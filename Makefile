.DEFAULT_GOAL := help
SHELL := /bin/bash
PREFIX ?= $(HOME)/.cmux-pet
BIN := $(PREFIX)/bin/cmux-pet

.PHONY: help build release test test-shell render verify install uninstall run stop restart log clean fmt

help: ## Muestra estos comandos
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "};{printf "  \033[1m%-12s\033[0m %s\n",$$1,$$2}'

build: ## Compila en modo debug
	swift build

release: ## Compila optimizado
	swift build -c release

test: ## Tests de la logica pura (Swift)
	swift test

test-shell: ## Tests de shell, instalador e integridad del repo
	./scripts/test-shell-hooks.sh
	./scripts/test-installer.sh
	./scripts/test-repo-integrity.sh

render: ## Dibuja cada estado a PNG en ./render para revisarlo a ojo
	swift build && ./.build/debug/cmux-pet --render ./render
	@echo "abre ./render/todos.png y ./render/panel.png"

verify: build test test-shell ## El gate completo: lo que CI corre
	@echo ""
	@echo "verificacion completa: compila, tests de logica, hooks de zsh, instalador e integridad"

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

clean: ## Borra artefactos de build
	rm -rf .build render
