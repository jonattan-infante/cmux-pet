.DEFAULT_GOAL := help
SHELL := /bin/bash
PREFIX ?= $(HOME)/.cmux-pet
BIN := $(PREFIX)/bin/cmux-pet

.PHONY: help build release test test-shell test-windows packs packs-remote render verify install uninstall run stop restart log clean fmt pr merge tag

# Este repo es personal. La cuenta activa de gh es estado global que cualquier
# otra sesion voltea, asi que el token se pide explicitamente por usuario en vez
# de confiar en cual quedo activa.
GH := GH_TOKEN=$(shell gh auth token --user jonattan-infante 2>/dev/null) gh

help: ## Muestra estos comandos
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "};{printf "  \033[1m%-12s\033[0m %s\n",$$1,$$2}'

build: ## Compila en modo debug
	swift build

release: ## Compila optimizado
	swift build -c release

test: ## Tests de la logica pura (Swift)
	swift test

test-shell: ## Tests de shell, instalador, integridad y mascotas
	./scripts/test-shell-hooks.sh
	./scripts/test-installer.sh
	./scripts/test-repo-integrity.sh
	./scripts/test-pet-packs.sh

test-windows: ## Tests del port de Windows (logica pura, corre en cualquier Python 3)
	cd windows && /usr/bin/python3 -m unittest discover -s tests -p "test_*.py"

packs: ## Valida las mascotas del repo y el indice del marketplace
	./scripts/test-pet-packs.sh

packs-remote: ## Igual, pero tambien clona y valida las mascotas de terceros
	./scripts/test-pet-packs.sh --remote

render: ## Dibuja cada estado a PNG en ./render para revisarlo a ojo
	swift build && ./.build/debug/cmux-pet --render ./render
	@echo "abre ./render/todos.png y ./render/panel.png"

verify: build test test-shell test-windows ## El gate completo: lo que CI corre
	@echo ""
	@echo "verificacion completa: compila, tests de logica, hooks de zsh,"
	@echo "instalador, integridad del repo, mascotas del marketplace y port de Windows"

install: release ## Instala en ~/.cmux-pet y engancha el shell
	./install.sh --from-source

uninstall: ## Quita el asistente y su enganche del shell
	./install.sh --uninstall

run: ## Arranca el asistente en primer plano (Ctrl-C para salir)
	swift build && ./.build/debug/cmux-pet

stop: ## Detiene el asistente
	-pkill -f 'cmux-pet' 2>/dev/null || true

restart: stop ## Reinstala el binario y reinicia
	@sleep 1
	$(MAKE) install
	@echo "abre una terminal nueva de cmux para que arranque"

log: ## Sigue el log en vivo
	tail -f $(PREFIX)/pet.log

fmt: ## Formatea el Swift (requiere swift-format)
	@command -v swift-format >/dev/null && swift-format -i -r Sources Tests || echo "swift-format no instalado, omitido"

# La @ es obligatoria: sin ella make imprime la linea y el token queda en pantalla.
pr: verify ## Abre un PR de la rama actual con la cuenta correcta
	@$(GH) pr create --fill --head "$$(git branch --show-current)"
	@echo "  auto-merge:  make merge"

merge: ## Deja la rama actual en auto-merge (entra sola cuando CI pase)
	@$(GH) pr merge --auto --squash "$$(git branch --show-current)"

# Publicar es un tag. CI verifica que el tag, VERSION y el CHANGELOG digan lo
# mismo y crea el release; ver docs/reference/versioning.md.
tag: ## Etiqueta la version de VERSION desde main al dia y la empuja (dispara el release)
	@test "$$(git branch --show-current)" = main || { echo "solo desde main"; exit 1; }
	@git fetch origin --quiet
	@test "$$(git rev-parse HEAD)" = "$$(git rev-parse origin/main)" || { echo "main no esta al dia con origin/main"; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "hay cambios sin commit"; exit 1; }
	@v="$$(tr -d '[:space:]' < VERSION)"; \
	  git rev-parse -q --verify "refs/tags/v$$v" >/dev/null && { echo "v$$v ya existe"; exit 1; }; \
	  git tag -a "v$$v" -m "cmux-pet $$v" && git push origin "v$$v" && \
	  echo "v$$v empujado; el release lo crea CI: $(GH_WEB)/actions"
GH_WEB := https://github.com/jonattan-infante/cmux-pet

clean: ## Borra artefactos de build
	rm -rf .build render
