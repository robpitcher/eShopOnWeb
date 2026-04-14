# Stage 2 — Characterization Tests

You are an automated coding agent running inside a GitHub Actions workflow.
Your job is to generate **black-box characterization tests** that lock in the
application's current observable behavior. This is a **pre-upgrade safety net** —
do not refactor, fix bugs, or change any existing code.

---

## Input Contract

Read the stage 1 inventory **before doing anything else**:

```
docs/modernization/stage-1/inventory.md
```

If this file does not exist or is empty, **abort immediately** with exit code 1
and print:

```
FATAL: Stage 1 inventory missing — docs/modernization/stage-1/inventory.md not found.
Stage 2 cannot proceed without its input contract.
```

Use the inventory to understand: projects, target frameworks, NuGet dependencies,
entry points, external I/O (database, HTTP, filesystem), configuration surface,
and upgrade risks. This drives what you test.

---

## What to Produce

### 1. Characterization Test Project

Create a new xUnit test project:

```
tests/CharacterizationTests/CharacterizationTests.csproj
```

**Project conventions** (match existing test projects in this repo):

- Target framework: `net7.0` (inherited from `Directory.Packages.props`)
- Use centrally-managed package versions (no explicit `Version` attributes)
- Required packages: `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`,
  `Microsoft.AspNetCore.Mvc.Testing`, `Microsoft.EntityFrameworkCore.InMemory`
- Set `<IsPackable>false</IsPackable>`
- Set `<RootNamespace>Microsoft.eShopWeb.CharacterizationTests</RootNamespace>`
- Add project references to `../../src/Web/Web.csproj` and
  `../../src/PublicApi/PublicApi.csproj` (and `../../src/ApplicationCore/ApplicationCore.csproj`
  if needed for service-level tests)

**Test fixtures:** Follow the pattern established by the existing functional tests:
- Use `WebApplicationFactory<T>` with in-memory database overrides
- See `tests/FunctionalTests/Web/WebTestFixture.cs` and
  `tests/FunctionalTests/PublicApi/ApiTestFixture.cs` for the pattern
- Create separate fixtures for the Web app and the PublicApi app

### 2. Test Categories and Coverage

Organize tests into folders matching these categories:

#### `ApiEndpoints/` — Public API behavioral lock-in
- Authentication endpoint (POST token request → 200 with valid creds, 401 with invalid)
- Catalog list endpoint (GET → 200, returns JSON with expected shape)
- Catalog item by ID (GET → 200 with valid ID, 404 with invalid)
- Create / Update / Delete catalog items (authenticated requests)
- Verify response status codes, content types, and JSON structure

#### `WebApp/` — Web application behavioral lock-in
- Home page loads (GET `/` → 200, contains expected product content)
- Catalog page filtering works
- Basket page requires authentication (redirect to login)
- Order page requires authentication
- Static assets are served

#### `Services/` — Key service behavior lock-in
- Catalog service returns seeded data through the application stack
- Basket operations (add/remove items) via the web application
- Order creation flow (end-to-end through HTTP)

#### `Configuration/` — Configuration loading verification
- Application starts successfully with default configuration
- Required services are registered in the DI container
- Database context is resolvable
- Identity system is configured

#### `DataAccess/` — Data access pattern verification
- Seeded catalog data is accessible
- Repository pattern returns expected data shapes
- Specification pattern works for filtering

**Every test must:**
- Be a `[Fact]` or `[Theory]` with descriptive name
- Assert on **current behavior** (not idealized behavior)
- Use `[Collection("Sequential")]` where tests share state
- Use `[Trait("Category", "<category>")]` for filtering
  (categories: `Api`, `Web`, `Service`, `Configuration`, `DataAccess`)

### 3. Baseline Document

Write a baseline report to:

```
docs/modernization/stage-2/baseline.md
```

The document must contain these sections:

```markdown
# Stage 2 — Characterization Test Baseline

## Summary
- Total test count: <N>
- Categories: Api (<n>), Web (<n>), Service (<n>), Configuration (<n>), DataAccess (<n>)
- All tests passing: yes/no
- Target framework: net7.0

## Covered Behavior
<For each category, list what observable behavior is locked in.>

## Explicitly NOT Covered
<List what is NOT tested and why. Be specific. Examples:>
- Blazor Admin (BlazorShared/BlazorAdmin) — WebAssembly apps require browser automation, out of scope for xUnit characterization
- Email sending — no email service configured in default app
- External payment processing — not present in this application
- CSS/JS rendering — not observable via HTTP response assertions
- Database migrations — characterization tests use in-memory provider
- Performance characteristics — not a behavioral concern

## Test Execution
- Command: `dotnet test tests/CharacterizationTests/ --configuration Release`
- Expected result: all tests pass against the pre-upgrade codebase
```

---

## Constraints

1. **No refactoring.** Do not modify any file under `src/`. Do not modify existing test projects.
2. **No new dependencies** beyond what's already in `Directory.Packages.props`.
   If you need a package not already listed, document it in the baseline and skip those tests.
3. **Tests must pass.** Run `dotnet test tests/CharacterizationTests/ --configuration Release`
   before finishing. If any test fails, fix the test (not the app). If behavior is
   genuinely untestable with the available tools, skip it and document why in the baseline.
4. **Black-box only.** Test through HTTP endpoints and public API surface.
   Do not test private methods or internal implementation details.
5. **In-memory database.** Override EF Core to use `UseInMemoryDatabase` so tests
   run without SQL Server. Follow existing test fixture patterns exactly.
6. **Narrow scope.** Characterization tests only. No upgrade work, no refactoring
   recommendations, no code quality improvements.

---

## Output Paths

| Artifact | Path |
|---|---|
| Test project | `tests/CharacterizationTests/CharacterizationTests.csproj` |
| Test source files | `tests/CharacterizationTests/**/*.cs` |
| Baseline document | `docs/modernization/stage-2/baseline.md` |

---

## Exit Criteria

This stage is **complete** when:

1. ✅ `tests/CharacterizationTests/` exists and builds without errors
2. ✅ `dotnet test tests/CharacterizationTests/ --configuration Release` passes — **zero failures**
3. ✅ `docs/modernization/stage-2/baseline.md` exists with all required sections
4. ✅ No files under `src/` were modified
