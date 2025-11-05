# Testing GraphQL Support in Hola.nvim

This guide covers how to test the GraphQL functionality in hola.nvim, including running automated tests and manual testing with the test server.

## Table of Contents
- [Automated Tests](#automated-tests)
- [Manual Testing with Test Server](#manual-testing-with-test-server)
- [Testing Scenarios](#testing-scenarios)
- [Troubleshooting](#troubleshooting)

## Automated Tests

### Running the Test Suite

The project includes comprehensive tests for GraphQL functionality located in `tests/hola/graphql_spec.lua`.

#### Prerequisites

1. **Install Neovim** (0.7.0 or higher)
2. **Install dependencies:**
   ```bash
   # The test script will auto-install plenary.nvim, but you can do it manually:
   mkdir -p deps
   git clone https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
   ```

#### Running Tests

**Option 1: Using the test script (recommended)**
```bash
bash scripts/test-and-lint.sh
```

Note: This requires `stylua` for linting. If you don't have it, you can skip linting and run tests directly:

**Option 2: Run tests directly with Neovim**
```bash
nvim --headless -u scripts/init.lua \
  -c "PlenaryBustedDirectory ./tests {minimal_init='./scripts/init.lua'}"
```

**Option 3: Run only GraphQL tests**
```bash
nvim --headless -u scripts/init.lua \
  -c "PlenaryBustedFile tests/hola/graphql_spec.lua {minimal_init='./scripts/init.lua'}"
```

### Test Coverage

The GraphQL test suite (`tests/hola/graphql_spec.lua`) covers:

- ✅ **Query parsing**: Simple queries, queries with variables, mutations
- ✅ **Variable handling**: Nested objects, arrays, complex structures
- ✅ **Request transformation**: Converting GRAPHQL to POST with JSON body
- ✅ **Response detection**: Identifying GraphQL responses with data/errors
- ✅ **Error handling**: Invalid JSON, malformed queries, validation errors
- ✅ **Query validation**: Bracket matching, string escaping, syntax checking

## Manual Testing with Test Server

For hands-on testing and development, use the included test server that provides a mock GraphQL endpoint.

### Step 1: Start the Test Server

```bash
python scripts/server.py
```

You should see:
```
Serving on http://0.0.0.0:8000
```

The server provides a GraphQL endpoint at `http://localhost:8000/graphql` with mock data for testing.

### Step 2: Set Up Environment Variables

Create a `.env` file in the project root (or use the provided `.env.example`):

```bash
# Copy the example file
cp .env.example .env

# Edit with your preferred values
cat > .env << 'EOF'
API_TOKEN=test_token_12345
API_URL=http://localhost:8000
ENVIRONMENT=development
EOF
```

### Step 3: Open Neovim with Test File

```bash
nvim -u scripts/init.lua examples.http
```

This loads hola.nvim in a minimal environment for testing.

### Step 4: Test GraphQL Requests

Navigate to any of the GraphQL examples in `examples.http` and press `:HolaSend` (or your configured keymap).

## Testing Scenarios

### 1. Simple GraphQL Query

**Test**: Basic query without variables

Navigate to this request in `examples.http`:
```http
### Simple GraphQL query without variables
GRAPHQL http://localhost:8000/graphql
Authorization: Bearer {{env:API_TOKEN}}

query {
  user(id: "1") {
    id
    name
    email
    posts {
      id
      title
    }
  }
}
```

**Expected Result:**
- Status: 200 OK
- Response body shows formatted JSON with user data
- Response includes nested posts array

**Verify:**
- ✅ Request is sent as POST with Content-Type: application/json
- ✅ Authorization header includes the Bearer token from .env
- ✅ Response is formatted JSON
- ✅ No errors in metadata view

### 2. Query with Variables

**Test**: Query using GraphQL variables

Navigate to:
```http
### GraphQL query with variables
GRAPHQL http://localhost:8000/graphql
Authorization: Bearer {{env:API_TOKEN}}

query GetUser($userId: ID!, $includeEmail: Boolean!) {
  user(id: $userId) {
    id
    name
    email @include(if: $includeEmail)
    posts {
      id
      title
      publishedAt
    }
  }
}

{
  "userId": "123",
  "includeEmail": true
}
```

**Expected Result:**
- Status: 200 OK
- Response shows user with ID "123"
- Email field is included (because `includeEmail: true`)

**Verify:**
- ✅ Variables are correctly parsed from JSON section
- ✅ Template variables ({{env:API_TOKEN}}) are resolved
- ✅ Response includes email field

### 3. GraphQL Mutation

**Test**: Creating data with a mutation

Navigate to:
```http
### GraphQL mutation with complex input
GRAPHQL http://localhost:8000/graphql
Authorization: Bearer {{env:API_TOKEN}}

mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    id
    title
    content
    author {
      id
      name
    }
    createdAt
  }
}

{
  "input": {
    "title": "Getting Started with GraphQL",
    "content": "GraphQL is a query language for APIs...",
    "authorId": "123",
    "tags": ["graphql", "api", "tutorial"]
  }
}
```

**Expected Result:**
- Status: 200 OK
- Response shows created post with generated ID
- Author data is nested correctly

**Verify:**
- ✅ Mutation is transformed to POST request
- ✅ Complex nested input variables are preserved
- ✅ Arrays in variables are handled correctly

### 4. Query with Fragments

**Test**: Using GraphQL fragments

Navigate to:
```http
### GraphQL with nested variables and fragments
GRAPHQL http://localhost:8000/graphql
Authorization: Bearer {{env:API_TOKEN}}

query SearchProducts($filters: ProductFilters!, $pagination: PaginationInput!) {
  products(filters: $filters, pagination: $pagination) {
    totalCount
    pageInfo {
      hasNextPage
      endCursor
    }
    items {
      ...ProductDetails
    }
  }
}

fragment ProductDetails on Product {
  id
  name
  price
  category
  inStock
}

{
  "filters": {
    "category": "electronics",
    "priceRange": {
      "min": 100,
      "max": 1000
    },
    "inStock": true
  },
  "pagination": {
    "first": 10,
    "after": null
  }
}
```

**Expected Result:**
- Status: 200 OK
- Response shows product list with pagination info
- Fragment fields are present in product items

**Verify:**
- ✅ Fragments are included in the query string
- ✅ Deeply nested variables work correctly
- ✅ Pagination info is returned

### 5. Error Handling

**Test**: GraphQL error responses

Create a test request with an error-triggering query:
```http
### Test GraphQL error handling
GRAPHQL http://localhost:8000/graphql
Authorization: Bearer {{env:API_TOKEN}}

query {
  errorTest {
    field
  }
}
```

**Expected Result:**
- Status: 200 OK (GraphQL errors use 200 status)
- Response body contains `errors` array
- Metadata view shows: ⚠️ GraphQL Errors with error messages

**Verify:**
- ✅ Errors are detected in response
- ✅ Error messages are displayed in metadata view (`:HolaToggle`)
- ✅ Error details include message and location info

### 6. Authentication Failure

**Test**: Missing or invalid authentication

Remove the Authorization header and test:
```http
### Test authentication failure
GRAPHQL http://localhost:8000/graphql

query {
  user(id: "1") {
    name
  }
}
```

**Expected Result:**
- Status: 401 Unauthorized
- Error message about authentication

**Verify:**
- ✅ Request fails with authentication error
- ✅ Error is displayed via virtual text

### 7. Template Variables in Queries

**Test**: Using template variables within GraphQL queries

```http
### Template variables in query
GRAPHQL http://localhost:8000/graphql
Authorization: Bearer {{env:API_TOKEN}}

query {
  user(id: "{{env:USER_ID}}") {
    name
  }
}
```

**Expected Result:**
- User ID is resolved from environment before sending
- Query executes with the substituted value

**Verify:**
- ✅ Template variables are resolved before transformation
- ✅ Query reaches server with actual values, not placeholders

## Testing Checklist

Use this checklist when testing GraphQL functionality:

### Core Functionality
- [ ] Simple queries without variables work
- [ ] Queries with variables parse correctly
- [ ] Mutations with input types work
- [ ] Fragments are preserved in queries
- [ ] Directives (@include, @skip) are supported

### Variable Handling
- [ ] Simple variables (strings, numbers, booleans)
- [ ] Nested objects in variables
- [ ] Arrays in variables
- [ ] Null values in variables

### Template Variables
- [ ] {{env:VAR}} works in headers
- [ ] {{env:VAR}} works in query text
- [ ] {{env:VAR}} works in variables JSON
- [ ] {{oauth:service}} resolves correctly

### Error Handling
- [ ] GraphQL errors are detected
- [ ] Errors displayed in metadata view
- [ ] Multiple errors shown correctly
- [ ] Authentication errors handled

### Response Display
- [ ] JSON response is auto-formatted
- [ ] Body view shows data
- [ ] Metadata view shows stats and errors
- [ ] Toggle between views works (:HolaToggle)
- [ ] JSON formatting toggle works (:HolaFormatJson)

## Advanced Testing

### Test with Real GraphQL APIs

You can test with real GraphQL endpoints by modifying the examples:

**GitHub GraphQL API:**
```http
GRAPHQL https://api.github.com/graphql
Authorization: Bearer YOUR_GITHUB_TOKEN

query {
  viewer {
    login
    name
    repositories(first: 5) {
      nodes {
        name
        description
      }
    }
  }
}
```

**SpaceX GraphQL API (public, no auth):**
```http
GRAPHQL https://spacex-production.up.railway.app/

query {
  launches(limit: 5) {
    mission_name
    launch_date_utc
    rocket {
      rocket_name
    }
  }
}
```

Note: Remove the Authorization header for public APIs.

### Test Performance

Monitor request timing in the metadata view:
- Simple queries should complete in < 100ms (local server)
- Complex queries with nested data < 500ms
- Check the "Time" field in metadata view

### Test Large Responses

Test with queries that return large datasets:
- Verify JSON formatting handles large responses
- Check that UI remains responsive
- Test scrolling in response window

## Troubleshooting

### Tests Won't Run

**Issue**: `nvim: command not found`
**Solution**: Ensure Neovim is installed and in your PATH

**Issue**: `plenary.nvim not found`
**Solution**: Run `git clone https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim`

### Test Server Issues

**Issue**: Server won't start
**Solution**:
- Check if port 8000 is already in use: `lsof -i :8000`
- Kill the process or use a different port in server.py

**Issue**: Connection refused
**Solution**:
- Verify server is running: `curl http://localhost:8000/hello`
- Check firewall settings

### GraphQL Requests Failing

**Issue**: "Authentication required"
**Solution**:
- Ensure .env file exists with API_TOKEN
- Check Authorization header format: `Bearer {{env:API_TOKEN}}`

**Issue**: "Invalid JSON in request body"
**Solution**:
- Verify variables section is valid JSON
- Check for trailing commas or syntax errors

**Issue**: Variables not substituting
**Solution**:
- Ensure .env file is in project root
- Restart Neovim to reload environment
- Check variable name matches exactly (case-sensitive)

### Response Display Issues

**Issue**: Response not showing
**Solution**:
- Check for errors with `:messages`
- Verify response window is open (should split right)
- Try `:HolaClose` and resend request

**Issue**: JSON not formatted
**Solution**:
- Check `json.auto_format` in config
- Manually toggle with `:HolaFormatJson`
- Verify response Content-Type is application/json

## Getting Help

If you encounter issues:

1. **Check logs**: `:messages` in Neovim
2. **Enable debug logging**: Set `log.level = "DEBUG"` in config
3. **Review test output**: Look for specific test failures
4. **Check server output**: Look at console where server.py is running
5. **Report issues**: Create an issue on GitHub with:
   - Neovim version (`:version`)
   - Error messages
   - Steps to reproduce
   - Request example that fails

## Contributing Tests

When adding new GraphQL features:

1. Add test cases to `tests/hola/graphql_spec.lua`
2. Add example requests to `examples.http`
3. Update mock responses in `scripts/server.py` if needed
4. Update this testing guide with new scenarios
5. Ensure all tests pass before submitting PR

Happy testing! 🎯
