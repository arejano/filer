# base_bui_lua - atalhos de desenvolvimento
#
#   make            compila o host
#   make run        abre a aplicacao
#   make smoke      roda os testes headless
#   make screenshot gera build/screenshot.png
#   make distclean  apaga o build (e dependencias baixadas)

BUI_GIT_TAG ?= v0.5.0
BUILD_DIR   ?= build
CMAKE       ?= cmake
JOBS        ?= 8

APP_BIN = $$(cat $(BUILD_DIR)/base-bui-lua.path)

.PHONY: all build run smoke screenshot clean distclean

all: build

build:
	$(CMAKE) -S . -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUI_GIT_TAG=$(BUI_GIT_TAG)
	$(CMAKE) --build $(BUILD_DIR) --target base-bui-lua -j $(JOBS)

run: build
	$(APP_BIN) $(BUI_ARGS) app/main.lua $(ARGS)

smoke: build
	$(APP_BIN) --headless tests/smoke.lua
	$(APP_BIN) --headless tests/libs.lua

screenshot: build
	$(APP_BIN) --headless scripts/screenshot.lua $(BUILD_DIR)/screenshot.ppm
	@if command -v magick >/dev/null 2>&1; then \
		magick $(BUILD_DIR)/screenshot.ppm $(BUILD_DIR)/screenshot.png; \
		echo "PNG: $(BUILD_DIR)/screenshot.png"; \
	elif command -v convert >/dev/null 2>&1; then \
		convert $(BUILD_DIR)/screenshot.ppm $(BUILD_DIR)/screenshot.png; \
		echo "PNG: $(BUILD_DIR)/screenshot.png"; \
	else \
		echo "PPM: $(BUILD_DIR)/screenshot.ppm (instale ImageMagick para PNG)"; \
	fi

clean:
	@test -f $(BUILD_DIR)/CMakeCache.txt && $(CMAKE) --build $(BUILD_DIR) --target clean || true

distclean:
	rm -rf $(BUILD_DIR)
