#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0036-add-runtime-api-catalog.patch"

for command in git go gofmt python3 sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done

[[ -f "${patch}" ]] || { echo "缺少 API 目录补丁：${patch}" >&2; exit 1; }
expected_sha="$(awk '$2 == "0036-add-runtime-api-catalog.patch" {print $1; exit}' "${source_dir}/SHA256SUMS")"
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0036 SHA-256 与 SHA256SUMS 不一致" >&2
    exit 1
}

expected_files="$({
    printf '%s\n' \
      backend/internal/api/api_catalog.go \
      backend/internal/api/api_catalog_test.go \
      backend/internal/api/routes.go \
      docs/openapi.yaml
} | sort)"
actual_files="$(git apply --numstat "${patch}" | awk '{print $3}' | sort)"
[[ "${actual_files}" == "${expected_files}" ]] || {
    echo "0036 变更文件集合异常" >&2
    diff -u <(printf '%s\n' "${expected_files}") <(printf '%s\n' "${actual_files}") >&2 || true
    exit 1
}

grep -Fq 'patchFeatures = append(patchFeatures, "api-catalog")' "${patch}"
grep -Fq 'api.GET("/catalog", s.apiCatalog(router))' "${patch}"
grep -Fq 'router.Routes()' "${patch}"
grep -Fq 'GET /api/catalog' "${repo_root}/README.md"
grep -Fq 'operationId: getAPICatalog' "${patch}"
grep -Fq 'session-or-development-key' "${patch}"
grep -Fq 'patched' "${patch}"

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-api-catalog.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}/backend/internal/api" "${work}/docs"
cat > "${work}/backend/internal/api/routes.go" <<'GO'
package api

func (s Server) registerRoutes(router *gin.Engine) {
	api := router.Group("/api")
	s.registerSystemRoutes(api)
	s.registerServerRoutes(api)
	s.registerContentRoutes(api)
	s.registerSecurityRoutes(api)
	s.registerWorldRoutes(api)
	s.registerFrontendRoutes(router)
}
GO
cat > "${work}/docs/openapi.yaml" <<'YAML'
paths:
  /patch/info:
    get:
      operationId: getPatchInfo
      tags: [system]
      security: []
      x-palpanel-permission: public
      responses:
        '200':
          description: Patch provenance, compatibility target, feature list, and build metadata.
          content:
            application/json:
              schema: {$ref: '#/components/schemas/PatchInfoEnvelope'}
  /auth/status:
    get:
      operationId: getAuthenticationStatus
YAML

git -C "${work}" init -q
git -C "${work}" apply --check "${patch}"
git -C "${work}" apply "${patch}"
grep -Fq 'api.GET("/catalog", s.apiCatalog(router))' "${work}/backend/internal/api/routes.go"
grep -Fq 'operationId: getAPICatalog' "${work}/docs/openapi.yaml"

for file in \
    "${work}/backend/internal/api/api_catalog.go" \
    "${work}/backend/internal/api/api_catalog_test.go"; do
    if [[ -n "$(gofmt -d "${file}")" ]]; then
        echo "Go 文件未通过 gofmt：${file}" >&2
        gofmt -d "${file}" >&2
        exit 1
    fi
done

python3 - "${work}/backend/internal/api/api_catalog.go" "${repo_root}/README.md" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
readme = Path(sys.argv[2]).read_text(encoding="utf-8")
required = [
    "GET /api/patch/info",
    "GET /api/catalog",
    "GET /api/inventory",
    "GET /api/pals",
    "PUT /api/bases/:id/name",
    "PUT /api/players/:id/annotation",
    "POST /api/patch/update",
    "PUT /api/security/paldefender/starter-gift",
]
for marker in required:
    if marker not in source:
        raise SystemExit(f"API catalog missing descriptor: {marker}")

for marker in (
    "/api/patch/info",
    "/api/catalog",
    "/api/inventory",
    "/api/pals",
    "/api/bases/{id}/workers",
    "/api/security/paldefender/starter-gift",
):
    if marker not in readme:
        raise SystemExit(f"README missing API documentation: {marker}")

if "router.Routes()" not in source or 'strings.HasPrefix(route.Path, "/api/")' not in source:
    raise SystemExit("catalog must enumerate and filter the runtime route table")
if not re.search(r"sort\.Slice\(routes", source):
    raise SystemExit("catalog routes must use deterministic sorting")
if 'route.Path != "/api"' not in source:
    raise SystemExit("catalog must reject frontend routes")
PY

compile="${work}/compile"
mkdir -p "${compile}/api" "${compile}/ginstub"
cp "${work}/backend/internal/api/api_catalog.go" "${compile}/api/"
cp "${work}/backend/internal/api/api_catalog_test.go" "${compile}/api/"
cat > "${compile}/go.mod" <<'MOD'
module palpanel

go 1.22

require github.com/gin-gonic/gin v0.0.0
replace github.com/gin-gonic/gin => ./ginstub
MOD
cat > "${compile}/ginstub/go.mod" <<'MOD'
module github.com/gin-gonic/gin

go 1.22
MOD
cat > "${compile}/ginstub/gin.go" <<'GO'
package gin

import (
	"encoding/json"
	"net/http"
)

const TestMode = "test"

func SetMode(string) {}

type H map[string]any
type HandlerFunc func(*Context)
type RouteInfo struct {
	Method      string
	Path        string
	Handler     string
	HandlerFunc HandlerFunc
}
type RoutesInfo []RouteInfo
type Engine struct{ routes RoutesInfo }

func New() *Engine { return &Engine{} }
func (e *Engine) GET(path string, handlers ...HandlerFunc) {
	var handler HandlerFunc
	if len(handlers) > 0 {
		handler = handlers[len(handlers)-1]
	}
	e.routes = append(e.routes, RouteInfo{Method: http.MethodGet, Path: path, Handler: "handler", HandlerFunc: handler})
}
func (e *Engine) Routes() RoutesInfo { return append(RoutesInfo(nil), e.routes...) }
func (e *Engine) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	for _, route := range e.routes {
		if route.Method == request.Method && route.Path == request.URL.Path {
			route.HandlerFunc(&Context{Writer: writer, Request: request})
			return
		}
	}
	writer.WriteHeader(http.StatusNotFound)
}

type Context struct {
	Writer  http.ResponseWriter
	Request *http.Request
}
func (c *Context) Status(status int) { c.Writer.WriteHeader(status) }
func (c *Context) JSON(status int, value any) {
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(status)
	_ = json.NewEncoder(c.Writer).Encode(value)
}
GO
cat > "${compile}/api/stub.go" <<'GO'
package api

import "github.com/gin-gonic/gin"

type Server struct{}
var patchFeatures []string
func ok(c *gin.Context, data any) { c.JSON(200, gin.H{"ok": true, "data": data}) }
GO
(
	cd "${compile}"
	go test ./api
)

echo "runtime API catalog regression passed."
