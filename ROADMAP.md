# Hola.nvim Development Roadmap

A comprehensive plan for evolving hola.nvim into a best-in-class Neovim REST client.

---

## Current State Analysis

### ✅ Core Strengths (v1.0)

**Provider System:**
- Variable resolution with `{{provider:identifier}}` syntax
- OAuth 2.0 client credentials flow with token caching
- HashiCorp Vault integration for secrets
- Environment variables (.env + OS env)
- References for variable aliasing

**HTTP Features:**
- Full HTTP method support (GET, POST, PUT, DELETE, PATCH, etc.)
- Async request execution via plenary.curl
- Multiple authentication methods (Basic, Bearer, ApiKey)
- Request separation with `###` syntax

**UI & Feedback:**
- Split window response display
- JSON auto-formatting with toggle
- Virtual text status indicators
- Response/metadata view switching
- Syntax highlighting for multiple content types

**Configuration:**
- Centralized config system
- Provider-specific settings
- Health checks for dependencies

**Testing:**
- 2,784 lines of tests across 12 modules
- OAuth, request parsing, JSON formatting covered
- Integration tests for workflows

### 🔍 Current Gaps

**High Impact:**
- ❌ No request history or session management
- ❌ No request chaining between calls
- ❌ Limited response analysis tools
- ❌ No clipboard integration

**Medium Impact:**
- ⚠️ UI module lacks dedicated tests
- ⚠️ No request collections or organization
- ⚠️ No dynamic variables (timestamps, UUIDs)
- ⚠️ Missing file upload support

**Lower Impact:**
- 📝 No GraphQL or WebSocket support
- 📝 No LSP or advanced IDE features
- 📝 No import/export capabilities

---

## Competitive Landscape

### Main Competitors (2024-2025)

1. **kulala.nvim** - Feature-rich with GraphQL, WebSocket, extensive auth
2. **rest.nvim** - Tree-sitter parser, pure Lua (archived)
3. **resty.nvim** - Telescope integration, Lua scripting
4. **nvim-rest-client** - VS Code compatibility, Go backend

### Hola.nvim Positioning

**Core Philosophy:** *Simplicity with Power*
- Provider-based architecture for extensibility
- Clean Lua-only implementation (no external dependencies beyond Neovim + plenary)
- Focus on developer workflow efficiency
- Maintainable, well-tested codebase

**Competitive Advantages:**
- Superior provider system (OAuth, Vault, env, refs)
- Clean architecture with excellent test coverage
- No complex dependencies or external tooling
- Configuration as code (Lua-based)

---

## Phase 1: Essential Features (Q1 2025)

### 🎯 Priority 1: Request History & Sessions

**Problem:** Re-running requests requires navigating back through files. No context preservation across sessions.

**Implementation Timeline:** 2-3 weeks

**Features:**

1. **Persistent History Storage**
   - JSON-based history in `~/.local/share/hola/history.json`
   - Store last 100 requests (configurable)
   - Includes: method, URL, headers, body, response status, timestamp, file location

2. **History Browser**
   - `:HolaHistory` opens fuzzy-searchable history list
   - Preview request and response inline
   - Filter by method, status code, URL pattern
   - Quick re-run with `<CR>`

3. **Quick Access**
   - `:HolaRepeat` - Re-run last request
   - `:HolaRepeatLast <n>` - Run nth previous request
   - Clear history: `:HolaClearHistory [days]`

4. **History UI**
   - Timestamp with relative time ("2 hours ago")
   - Color-coded status codes (green 2xx, yellow 3xx, red 4xx/5xx)
   - Show response time
   - Search across all history fields

**Configuration:**
```lua
require('hola').setup({
  history = {
    enabled = true,
    max_entries = 100,
    storage_path = vim.fn.stdpath('data') .. '/hola/history.json',
    exclude_patterns = { '/health$', '/ping$' },  -- Don't save these
  }
})
```

**Success Metrics:**
- Reduces repeat request time by 80%
- Used in 60% of user sessions
- Zero data corruption issues

---

### 🎯 Priority 2: Response Content Tools

**Problem:** Extracting data from responses requires manual selection or external tools.

**Implementation Timeline:** 2 weeks

**Features:**

1. **Clipboard Operations**
   - `:HolaCopy` - Copy entire response to clipboard
   - `:HolaCopy body` - Copy response body only
   - `:HolaCopy headers` - Copy all headers
   - `:HolaCopy $.data.token` - Copy JSON path value

2. **Save to File**
   - `:HolaSave /path/to/file.json` - Save response
   - Auto-detect format based on content-type
   - Template support: `:HolaSave response-{{timestamp}}.json`

3. **In-Response Search**
   - `/` in response window - Search with highlighting
   - `n/N` navigation between matches
   - `:HolaSearch pattern` - Search from command line

4. **JSON Path Extraction**
   - Extract nested values using JSONPath syntax
   - Highlight matching paths in response
   - Copy extracted values

5. **Response Comparison**
   - `:HolaDiff` - Compare current response with previous
   - Side-by-side diff view
   - Highlight added/removed/changed fields

**Keybindings (in response window):**
```lua
-- Default keybindings
y     -- Copy entire response
yb    -- Copy response body
yh    -- Copy headers
/     -- Search in response
gd    -- Go to definition (for JSON references)
```

**Success Metrics:**
- Eliminates 90% of manual copy/paste operations
- Search used in 30% of requests
- Diff feature adoption by advanced users

---

### 🎯 Priority 3: Request Collections

**Problem:** Managing multiple related requests is difficult. No way to organize API endpoints.

**Implementation Timeline:** 2-3 weeks

**Features:**

1. **Request Naming**
   ```http
   ### @name Login
   POST {{env:API_URL}}/auth/login
   Content-Type: application/json

   {"username": "admin", "password": "secret"}

   ### @name GetUser
   GET {{env:API_URL}}/users/me
   Authorization: Bearer {{oauth:service}}
   ```

2. **Collections Browser**
   - `:HolaCollections` - Open collection browser
   - Lists all named requests in project
   - Fuzzy search by name
   - Execute directly from browser

3. **Request Tagging**
   ```http
   ### @name Login
   ### @tags auth,admin
   POST {{env:API_URL}}/auth/login
   ```
   - Filter by tags: `:HolaCollections auth`
   - Show all requests with specific tag

4. **Favorites**
   - `:HolaFavorite` - Add current request to favorites
   - `:HolaFavorites` - Show favorite requests
   - Persistent across sessions

5. **Quick Jump**
   - `]r` / `[r` - Next/previous request in file
   - `:HolaNext`, `:HolaPrev` commands
   - Jump to request by name: `:HolaJump Login`

**Configuration:**
```lua
require('hola').setup({
  collections = {
    enabled = true,
    show_in_statusline = true,  -- Show current request name
    auto_name_from_url = false,  -- Auto-generate names from endpoint
  }
})
```

**Success Metrics:**
- 70% of projects use named requests
- Average 15 requests per collection
- Faster navigation to specific endpoints

---

## Phase 2: Workflow Automation (Q2 2025)

### 🎯 Priority 4: Request Chaining

**Problem:** Testing multi-step workflows requires manually copying tokens/IDs between requests.

**Implementation Timeline:** 3-4 weeks

**Features:**

1. **Variable Capture from Responses**
   ```http
   ### @name Login
   POST {{env:API_URL}}/auth/login
   Content-Type: application/json
   ### @capture token=$.data.access_token
   ### @capture user_id=$.data.user.id

   {"username": "admin", "password": "secret"}

   ###
   ### Uses captured variables
   GET {{env:API_URL}}/users/{{user_id}}
   Authorization: Bearer {{token}}
   ```

2. **Chained Execution**
   - `:HolaSendChain [name1] [name2]` - Execute sequence
   - Stop on first error (configurable)
   - Visual progress indicator
   - Summary at end showing all statuses

3. **Conditional Execution**
   ```http
   ### @name CreateUser
   ### @if status=201
   POST {{env:API_URL}}/users

   ### @name SendWelcomeEmail
   ### @requires CreateUser
   ### @if previous.status=201
   POST {{env:API_URL}}/emails/welcome
   ```

4. **Pre/Post Request Scripts**
   ```http
   ### @name Login
   ### @pre-request
   -- Lua script to run before request
   local timestamp = os.time()
   hola.set_var('request_time', timestamp)
   ### @end

   ### @post-request
   -- Validate response
   if response.status ~= 200 then
     error('Login failed')
   end
   ### @end

   POST {{env:API_URL}}/auth/login
   ```

5. **Request Dependencies**
   - Automatic dependency resolution
   - Execute prerequisites before main request
   - Cache dependency responses
   - Show dependency graph

**Configuration:**
```lua
require('hola').setup({
  chaining = {
    enabled = true,
    stop_on_error = true,
    delay_between_requests = 0,  -- ms
    show_progress = true,
  }
})
```

**Success Metrics:**
- 40% of workflows use chaining
- Reduces test time by 60%
- Zero dependency resolution bugs

---

### 🔧 Priority 5: Dynamic Variables

**Problem:** Need runtime-generated values for testing (timestamps, UUIDs, etc.).

**Implementation Timeline:** 2 weeks

**Features:**

1. **Built-in Functions**
   ```http
   POST {{env:API_URL}}/events
   Content-Type: application/json

   {
     "id": "{{$uuid}}",
     "timestamp": "{{$timestamp}}",
     "date": "{{$iso8601}}",
     "random": "{{$randomInt 1 100}}",
     "email": "{{$randomEmail}}"
   }
   ```

2. **Available Functions**
   - `{{$timestamp}}` - Unix timestamp (seconds)
   - `{{$timestamp_ms}}` - Unix timestamp (milliseconds)
   - `{{$iso8601}}` - ISO 8601 datetime
   - `{{$date "YYYY-MM-DD"}}` - Custom date format
   - `{{$uuid}}` - UUID v4
   - `{{$randomInt min max}}` - Random integer in range
   - `{{$randomFloat min max}}` - Random float in range
   - `{{$randomString length}}` - Random alphanumeric string
   - `{{$randomEmail}}` - Random email address
   - `{{$randomUrl}}` - Random URL
   - `{{$base64 "text"}}` - Base64 encode
   - `{{$hash "text" "sha256"}}` - Hash function

3. **Arithmetic Operations**
   ```http
   # Future timestamp (1 hour from now)
   {{$timestamp + 3600}}

   # Past date
   {{$date "YYYY-MM-DD" -7}}  # 7 days ago
   ```

4. **Custom Functions**
   ```lua
   require('hola').setup({
     dynamic_vars = {
       custom_functions = {
         -- Custom function
         tenant_id = function()
           return vim.fn.system('get-tenant-id'):gsub('\n', '')
         end,

         -- Function with parameters
         formatted_name = function(first, last)
           return string.format('%s_%s', first:lower(), last:lower())
         end
       }
     }
   })
   ```

   Usage: `{{$tenant_id}}`, `{{$formatted_name "John" "Doe"}}`

5. **Environment-specific Values**
   - Different values per environment
   - Override in .hola/resolution.lua

**Success Metrics:**
- Used in 50% of requests
- Reduces manual value generation
- Zero function errors

---

### 🔧 Priority 6: Request Templates

**Problem:** Creating similar requests involves repetitive copying and editing.

**Implementation Timeline:** 2 weeks

**Features:**

1. **Template Library**
   - Built-in templates in `.hola/templates/`
   - User templates in `~/.config/hola/templates/`
   - Project-specific templates

2. **Insert Template**
   - `:HolaTemplate <name>` - Insert at cursor
   - Fuzzy search for template
   - Preview before inserting

3. **Template Format**
   ```http
   ### @template REST-GET
   ### @description Get a single resource
   GET {{env:API_URL}}/{{resource}}/{{id}}
   Authorization: Bearer {{oauth:{{service}}}}
   Content-Type: application/json
   ```

4. **Built-in Templates**
   - `rest-get` - Simple GET request
   - `rest-post` - POST with JSON body
   - `rest-put` - PUT update
   - `rest-delete` - DELETE request
   - `oauth-client-creds` - OAuth client credentials flow
   - `oauth-password` - OAuth password grant
   - `basic-auth` - Basic authentication
   - `paginated-get` - GET with pagination
   - `file-upload` - Multipart file upload
   - `graphql-query` - GraphQL query
   - `webhook-test` - Webhook POST

5. **Template Variables**
   ```http
   ### @template custom-post
   POST {{INPUT:API_URL:Enter API URL}}
   Content-Type: {{SELECT:content-type:application/json,application/xml}}

   {{INPUT:body:Enter request body}}
   ```
   - `{{INPUT:name:prompt}}` - Prompt for input
   - `{{SELECT:name:opt1,opt2}}` - Select from options
   - `{{DEFAULT:name:value}}` - Default if not provided

**Configuration:**
```lua
require('hola').setup({
  templates = {
    enabled = true,
    paths = {
      '~/.config/hola/templates',
      '.hola/templates',
    },
    prompt_for_variables = true,
  }
})
```

**Success Metrics:**
- Reduces request creation time by 70%
- Users create 3+ custom templates
- Template library grows to 20+ templates

---

## Phase 3: Advanced Features (Q3 2025)

### 🚀 Priority 7: GraphQL Support

**Problem:** GraphQL requests need special handling for queries, mutations, variables.

**Implementation Timeline:** 3-4 weeks

**Features:**

1. **GraphQL Syntax**
   ```graphql
   ### @name GetUser
   ### @type graphql
   POST {{env:GRAPHQL_URL}}/graphql
   Content-Type: application/json

   query GetUser($id: ID!) {
     user(id: $id) {
       id
       name
       email
       posts {
         title
         createdAt
       }
     }
   }

   # Variables
   {
     "id": "{{user_id}}"
   }
   ```

2. **GraphQL Features**
   - Syntax highlighting for queries/mutations
   - Query validation
   - Variable extraction and validation
   - Fragment support
   - Response formatting specific to GraphQL

3. **Schema Introspection**
   - `:HolaGraphQLSchema` - Fetch and cache schema
   - Auto-completion for fields and types
   - Inline documentation on hover
   - Query validation against schema

4. **GraphQL Templates**
   - Common query patterns
   - Mutation templates
   - Subscription templates

**Success Metrics:**
- GraphQL adoption by 20% of users
- Zero query parsing errors
- Schema caching works reliably

---

### 🚀 Priority 8: WebSocket Support

**Problem:** Testing WebSocket connections requires external tools.

**Implementation Timeline:** 4-5 weeks

**Features:**

1. **WebSocket Syntax**
   ```
   ### @name WebSocket Connection
   ### @type websocket
   WEBSOCKET {{env:WS_URL}}/notifications
   Authorization: Bearer {{oauth:service}}

   # Send on connect
   > {"type": "subscribe", "channel": "updates"}

   # Expected messages (for validation)
   < {"type": "confirmation"}

   # Send after delay
   @after 5s
   > {"type": "ping"}
   ```

2. **Connection Management**
   - Connect/disconnect controls
   - Connection status indicator
   - Automatic reconnection (configurable)
   - Ping/pong monitoring

3. **Message History**
   - Show all sent and received messages
   - Timestamps for each message
   - JSON formatting for structured messages
   - Export message history

4. **Interactive Sending**
   - `:HolaWSend <message>` - Send message on active connection
   - Pre-defined messages in .http file
   - Message templates

5. **Connection Duration**
   - Show connection uptime
   - Messages per second
   - Bandwidth usage

**Configuration:**
```lua
require('hola').setup({
  websocket = {
    enabled = true,
    auto_reconnect = true,
    reconnect_delay = 5000,  -- ms
    ping_interval = 30000,   -- ms
    max_message_size = 1048576,  -- 1MB
  }
})
```

**Success Metrics:**
- WebSocket feature used by 15% of users
- Stable connections for extended periods
- No memory leaks

---

### 🚀 Priority 9: File Uploads

**Problem:** Testing file upload endpoints requires external tools or curl commands.

**Implementation Timeline:** 2-3 weeks

**Features:**

1. **Multipart Form Data**
   ```http
   POST {{env:API_URL}}/upload
   Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

   ------WebKitFormBoundary
   Content-Disposition: form-data; name="title"

   My Document
   ------WebKitFormBoundary
   Content-Disposition: form-data; name="file"; filename="doc.pdf"
   Content-Type: application/pdf

   @file ./documents/doc.pdf
   ------WebKitFormBoundary--
   ```

2. **File References**
   - `@file /path/to/file` - Include file content
   - Relative paths from .http file location
   - Binary file support
   - Auto-detect content type

3. **Upload Progress**
   - Progress bar for large files
   - Upload speed indicator
   - Estimated time remaining
   - Cancel upload capability

4. **Multiple Files**
   ```http
   POST {{env:API_URL}}/upload-multiple
   Content-Type: multipart/form-data

   @files ./documents/*.pdf
   ```

5. **Base64 Inline**
   ```http
   POST {{env:API_URL}}/image
   Content-Type: application/json

   {
     "image": "{{$fileBase64 ./image.png}}"
   }
   ```

**Success Metrics:**
- Supports files up to 100MB
- Upload progress accurate within 5%
- Zero file corruption issues

---

### 🔧 Priority 10: Enhanced Authentication

**Problem:** Some APIs use advanced auth methods not currently supported.

**Implementation Timeline:** 3-4 weeks

**Features:**

1. **AWS Signature V4**
   - Automatic AWS request signing
   - Support for all AWS services
   - Credential provider support

   ```http
   ### @auth aws-sigv4
   ### @aws-region us-east-1
   ### @aws-service s3
   GET {{env:AWS_API}}/bucket/object
   ```

2. **Digest Authentication**
   - Full RFC 2617 implementation
   - QOP support
   - Nonce caching

3. **NTLM Authentication**
   - Windows authentication support
   - Domain/workgroup handling

4. **Certificate-Based (mTLS)**
   ```http
   ### @auth mtls
   ### @cert ./client.crt
   ### @key ./client.key
   GET {{env:API_URL}}/secure
   ```

5. **Auth Profiles**
   ```lua
   -- .hola/resolution.lua
   return {
     auth_profiles = {
       production = {
         type = 'aws-sigv4',
         region = 'us-east-1',
         service = 'execute-api',
       },
       staging = {
         type = 'oauth',
         provider = 'auth0-staging',
       }
     }
   }
   ```

   Usage: `### @auth-profile production`

**Success Metrics:**
- Each auth method thoroughly tested
- Zero security vulnerabilities
- Performance impact < 10ms per request

---

## Phase 4: IDE Integration (Q4 2025)

### 🚀 Priority 11: Telescope Integration

**Implementation Timeline:** 2 weeks

**Features:**

1. **Request Finder**
   - `:Telescope hola requests` - Find all requests in project
   - Fuzzy search by name, URL, method
   - Live preview of request and last response
   - Execute request from Telescope

2. **History Browser**
   - `:Telescope hola history` - Browse request history
   - Filter by date, status, method
   - Preview responses
   - Quick re-run

3. **Collection Browser**
   - `:Telescope hola collections` - Browse collections
   - Group by file or tag
   - Show request count per collection

4. **Variable Browser**
   - `:Telescope hola variables` - Show all variables
   - See resolved values
   - Source provider information
   - Quick copy to clipboard

**Success Metrics:**
- Used by 60% of Telescope users
- Faster than manual navigation
- High user satisfaction

---

### 🚀 Priority 12: LSP for .http Files

**Implementation Timeline:** 6-8 weeks

**Features:**

1. **Diagnostics**
   - Syntax errors in HTTP requests
   - Invalid header names/values
   - Missing required headers
   - Variable resolution failures
   - URL validation

2. **Completion**
   - HTTP methods (GET, POST, etc.)
   - Common headers with values
   - Content-Type values
   - Variable names (from all providers)
   - Status code explanations

3. **Hover Documentation**
   - Status code meanings
   - Header explanations
   - Variable values (resolved)
   - Authentication method docs

4. **Go-to-Definition**
   - Jump to variable definition
   - Navigate to referenced requests
   - Find provider configuration

5. **Code Actions**
   - Generate request from OpenAPI
   - Convert to curl command
   - Add missing headers
   - Fix syntax errors

6. **Inline Hints**
   - Show resolved variable values
   - Display request size
   - Authentication status

**Configuration:**
```lua
-- Integrate with nvim-lspconfig
require('lspconfig').hola.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})
```

**Success Metrics:**
- <100ms completion latency
- 95%+ diagnostic accuracy
- Reduces syntax errors by 80%

---

### 🚀 Priority 13: Import/Export

**Implementation Timeline:** 3-4 weeks

**Features:**

1. **Export to curl**
   - `:HolaExport curl` - Generate curl command
   - Include all resolved variables
   - Proper escaping and formatting
   - Copy to clipboard

2. **Import from Postman**
   - `:HolaImport postman <file>` - Import collection
   - Convert to .http format
   - Preserve folder structure
   - Map variables to providers

3. **Import from OpenAPI**
   - `:HolaImport openapi <spec-url>` - Generate requests from spec
   - Create one request per endpoint
   - Include all parameters
   - Generate example bodies from schema

4. **Export to Postman**
   - `:HolaExport postman <file>` - Export collection
   - Maintain compatibility with Postman

5. **Import from HAR**
   - `:HolaImport har <file>` - Import from HTTP Archive
   - Useful for converting browser traffic
   - Filter by domain

6. **Export as Documentation**
   - `:HolaExport markdown` - Generate API docs
   - Include request/response examples
   - Auto-generate from collections

**Success Metrics:**
- 95%+ import success rate
- Exports work in target tools
- Users migrate from other tools

---

### 🔧 Priority 14: OpenAPI Integration

**Implementation Timeline:** 4-5 weeks

**Features:**

1. **Schema Loading**
   - `:HolaOpenAPI <url>` - Load OpenAPI spec
   - Cache locally for offline use
   - Support v2 (Swagger) and v3

2. **Request Generation**
   - Generate .http files from spec
   - One file per tag/resource
   - Include all operations
   - Example request bodies

3. **Request Validation**
   - Validate request against spec
   - Check required parameters
   - Validate body schema
   - Alert on spec changes

4. **Response Validation**
   - Validate response schema
   - Check status codes
   - Validate headers
   - Show schema violations

5. **Auto-completion**
   - Parameter names from spec
   - Enum values
   - Example values

6. **Living Documentation**
   - Keep requests in sync with spec
   - Highlight deprecated endpoints
   - Show operation descriptions

**Configuration:**
```lua
require('hola').setup({
  openapi = {
    enabled = true,
    spec_urls = {
      ['myapi'] = 'https://api.example.com/openapi.json',
    },
    validate_requests = true,
    validate_responses = true,
    cache_ttl = 3600,  -- seconds
  }
})
```

**Success Metrics:**
- Prevents 80% of schema violations
- Speeds up API exploration by 50%
- High adoption for OpenAPI users

---

## Phase 5: Testing & Quality (Ongoing)

### 🔧 Priority 15: Response Assertions

**Implementation Timeline:** 3-4 weeks

**Features:**

1. **Assertion Syntax**
   ```http
   POST {{env:API_URL}}/users
   Content-Type: application/json
   ### @assert status=201
   ### @assert header.content-type=application/json
   ### @assert body.$.data.id exists
   ### @assert body.$.data.email matches .*@example\.com
   ### @assert response_time < 500

   {"name": "John", "email": "john@example.com"}
   ```

2. **Assertion Types**
   - **Status**: `status=200`, `status>=200`, `status<400`
   - **Headers**: `header.name=value`, `header.name contains value`
   - **Body**: JSON path assertions with exists, equals, contains, matches
   - **Performance**: `response_time < 1000`
   - **Size**: `response_size < 1048576`

3. **Test Suites**
   ```http
   ### @suite User Management
   ### @name Create User
   ### @assert status=201
   POST {{env:API_URL}}/users

   ### @name Get User
   ### @assert status=200
   ### @assert body.$.name=John
   GET {{env:API_URL}}/users/{{user_id}}

   ### @name Delete User
   ### @assert status=204
   DELETE {{env:API_URL}}/users/{{user_id}}
   ```

4. **Run Test Suite**
   - `:HolaTest` - Run all assertions in file
   - `:HolaTest <suite>` - Run specific suite
   - Show pass/fail summary
   - Detailed failure messages

5. **CI/CD Integration**
   ```bash
   # Headless execution
   nvim --headless -c "lua require('hola').test_file('api.http')" -c "qa"
   ```
   - Exit code 0 on success, 1 on failure
   - JSON output for parsing
   - JUnit XML export

**Configuration:**
```lua
require('hola').setup({
  assertions = {
    enabled = true,
    stop_on_failure = false,
    show_summary = true,
    export_format = 'json',  -- json, junit, tap
  }
})
```

**Success Metrics:**
- Used for API testing by 30% of users
- Catches 90% of regressions
- Reliable CI/CD integration

---

### 🔧 Priority 16: Performance & Benchmarking

**Implementation Timeline:** 2-3 weeks

**Features:**

1. **Request Timing**
   - DNS lookup time
   - TCP connection time
   - TLS handshake time
   - Server processing time
   - Transfer time
   - Total time

2. **Benchmarking Mode**
   ```http
   ### @benchmark iterations=100 concurrency=10
   GET {{env:API_URL}}/users
   ```
   - Run request N times
   - Concurrent requests support
   - Statistical analysis (min, max, mean, median, p95, p99)
   - Throughput (req/s)

3. **Performance Metrics**
   - Response size (headers + body)
   - Bandwidth usage
   - Request rate limiting detection
   - Connection pooling stats

4. **Performance Profiling**
   - Profile variable resolution time
   - Provider resolution breakdown
   - Request parsing time
   - Response formatting time

5. **Visual Timing**
   - Waterfall chart in response window
   - Color-coded timing bars
   - Identify bottlenecks

6. **Comparison**
   - Compare performance across runs
   - Track performance over time
   - Alert on performance regression

**Configuration:**
```lua
require('hola').setup({
  performance = {
    show_timing = true,
    detailed_timing = false,  -- DNS, TCP, TLS breakdown
    benchmark_defaults = {
      iterations = 10,
      concurrency = 1,
    }
  }
})
```

**Success Metrics:**
- Timing accuracy within 5ms
- Benchmark mode handles 1000+ iterations
- Helps identify performance issues

---

### 🔧 Priority 17: Enhanced Testing

**Implementation Timeline:** Ongoing

**Goals:**

1. **Complete Test Coverage**
   - UI module tests (currently missing)
   - Vault provider comprehensive tests
   - End-to-end integration tests
   - Edge case coverage
   - Target: 90%+ coverage

2. **Performance Tests**
   - Request parsing benchmarks
   - Variable resolution performance
   - Response formatting speed
   - Memory usage tests
   - No regressions in performance

3. **Reliability Tests**
   - Network failure scenarios
   - Timeout handling
   - Large response handling (100MB+)
   - Concurrent request handling
   - Provider failure modes

4. **Security Tests**
   - Secret leakage prevention
   - Path traversal protection
   - Command injection prevention
   - XSS in response display

5. **Compatibility Tests**
   - Neovim version matrix (0.7+)
   - Different OS (Linux, macOS, Windows)
   - plenary.nvim versions

**Success Metrics:**
- 90%+ test coverage
- All tests pass on CI
- Zero critical bugs in production
- Performance regressions caught early

---

## Phase 6: Polish & UX (2026)

### 🔧 Priority 18: Enhanced UI/UX

**Implementation Timeline:** 4-6 weeks

**Features:**

1. **Response Window Improvements**
   - Collapsible sections (headers, body, timing)
   - Tabs for multiple concurrent requests
   - Split view: request on left, response on right
   - Diff view for before/after comparisons

2. **Visual Feedback**
   - Loading spinner during request
   - Progress bar for downloads
   - Color-coded status messages
   - Toast notifications (optional)

3. **Customizable Layout**
   - Configurable window positions
   - Float, split, vsplit, tab options
   - Resize response window
   - Save layout preferences

4. **Syntax Highlighting**
   - Custom .http file tree-sitter grammar
   - Better variable highlighting
   - Diff syntax for comparisons

5. **Status Line Integration**
   - Show current request name
   - Last request status
   - Active connections (WebSocket)

6. **Themes**
   - Response window theming
   - Color schemes for status codes
   - Accessible color modes

**Configuration:**
```lua
require('hola').setup({
  ui = {
    layout = 'vsplit',  -- vsplit, split, float, tab
    position = 'right',
    width = 80,  -- or percentage: '50%'
    height = '80%',
    border = 'rounded',
    collapsible_sections = true,
    show_icons = true,
    theme = 'auto',  -- auto, light, dark
  }
})
```

**Success Metrics:**
- High user satisfaction
- Reduces visual clutter
- Customizable to user preference

---

### 🔧 Priority 19: Better Error Messages

**Implementation Timeline:** 2 weeks

**Features:**

1. **HTTP Status Explanations**
   - Show human-readable status descriptions
   - Common causes for error codes
   - Suggested fixes

2. **Curl Error Details**
   - Translate curl error codes to readable messages
   - Network troubleshooting hints
   - Connection failure diagnostics

3. **Provider Errors**
   - Clear messages for variable resolution failures
   - OAuth token errors with refresh suggestions
   - Vault authentication failures with fix steps

4. **Validation Errors**
   - Syntax errors with line numbers
   - Highlight problematic lines
   - Suggest corrections

5. **Contextual Help**
   - `:HolaHelp <error-code>` - Show detailed help
   - Link to documentation
   - Community solutions

**Success Metrics:**
- 80% of errors self-resolve from messages
- Reduced support requests
- Faster debugging

---

## Technical Debt & Maintenance

### Ongoing Priorities

1. **Code Quality**
   - Refactor complex functions (e.g., `parse_request`)
   - Add type annotations throughout
   - Improve documentation
   - Regular dependency updates

2. **Performance**
   - Optimize variable resolution (caching, lazy loading)
   - Reduce memory footprint
   - Async operation improvements
   - Response streaming for large payloads

3. **Security**
   - Regular security audits
   - Dependency vulnerability scanning
   - Secret handling best practices
   - Secure defaults

4. **Documentation**
   - Comprehensive user guide
   - Video tutorials
   - API reference
   - Migration guides

5. **Community**
   - Issue triage and response
   - Feature request evaluation
   - Pull request review
   - Release notes

---

## Success Metrics & KPIs

### User Adoption
- 🎯 GitHub stars > 500 within 12 months
- 🎯 Active users > 1000 within 18 months
- 🎯 Community contributions > 20 PRs/year
- 🎯 Average issue response time < 48 hours

### Technical Excellence
- 🎯 Test coverage > 90%
- 🎯 Zero critical bugs in core functionality
- 🎯 Request parsing overhead < 50ms
- 🎯 Memory usage < 50MB for typical sessions
- 🎯 Plugin load time < 100ms

### Developer Experience
- 🎯 Setup time < 5 minutes for new users
- 🎯 Common workflows < 3 commands
- 🎯 Error messages clear and actionable
- 🎯 Documentation coverage 100%
- 🎯 User satisfaction > 4.5/5

### Ecosystem
- 🎯 Integration with 5+ popular plugins
- 🎯 10+ community templates
- 🎯 Active community discussions
- 🎯 Stable plugin API for extensions

---

## Contributing

We welcome contributions! Here's how to get involved:

### For Developers
1. Check the [Issues](https://github.com/malev/hola.nvim/issues) for open tasks
2. Read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines
3. Join [Discussions](https://github.com/malev/hola.nvim/discussions) for feature proposals

### For Users
1. Report bugs with detailed reproduction steps
2. Request features with use cases
3. Share your workflows and templates
4. Write tutorials and guides

### Development Principles
- **Tests First**: All features must have comprehensive tests
- **Backward Compatibility**: Maintain compatibility with existing .http files
- **Clean Code**: Follow existing patterns and conventions
- **Documentation**: Document all new features in README and examples
- **Performance**: Consider performance impact of new features

---

## Release Strategy

### Versioning
- **Major (x.0.0)**: Breaking changes, major features
- **Minor (0.x.0)**: New features, backward compatible
- **Patch (0.0.x)**: Bug fixes, minor improvements

### Release Cycle
- **Patch releases**: As needed for critical bugs
- **Minor releases**: Every 4-6 weeks
- **Major releases**: Every 6-12 months

### Deprecation Policy
- Features deprecated with 6-month notice
- Backward compatibility for at least 2 major versions
- Clear migration guides for breaking changes

---

## Competitive Positioning (2025)

### Differentiation Strategy

**vs. kulala.nvim:**
- Simpler, more maintainable codebase
- Superior provider architecture
- Better OAuth/Vault integration
- Focus on reliability over feature count

**vs. rest.nvim:**
- Active maintenance (rest.nvim is archived)
- Modern Neovim features
- Better testing and quality
- Comprehensive documentation

**vs. resty.nvim:**
- More comprehensive provider system
- Better authentication support
- Stronger testing framework
- Cleaner architecture

**vs. Postman/Insomnia:**
- Native Neovim integration
- Text-based, version-controllable
- Faster workflow for keyboard users
- No Electron, no GUI overhead

### Target Audience

**Primary:**
- Backend developers working with REST APIs
- DevOps engineers testing infrastructure APIs
- QA engineers writing API tests
- Developers who prefer CLI/TUI tools

**Secondary:**
- Full-stack developers
- Platform engineers
- Site reliability engineers
- Security researchers (API testing)

---

## Future Vision (2026+)

### Long-term Goals

1. **Best-in-class REST client for Neovim**
   - Feature parity with GUI tools
   - Superior workflow efficiency
   - Rock-solid reliability

2. **Extensible Platform**
   - Plugin ecosystem for custom providers
   - Integration with other tools
   - API for external tools

3. **Community Hub**
   - Template marketplace
   - Shared collections
   - Best practices repository

4. **Enterprise Ready**
   - Team collaboration features
   - SSO integration
   - Audit logging
   - Compliance features

### Experimental Features

- AI-powered request generation from natural language
- Automatic API discovery from codebases
- Smart request recommendations
- Performance anomaly detection
- Auto-generated tests from API usage

---

**Last Updated:** 2025-11-05
**Version:** 2.0
**Status:** Living Document

*This roadmap is continuously updated based on user feedback, competitive landscape, and development discoveries. Join the discussion to shape the future of hola.nvim!*
