# Rails Test Suite Failure Summary

Total: 75 failures, 2 errors

## Breakdown by Test Category:

### 1. **Controllers** (24 failures total)
- **PdfTemplatesControllerTest** (12 failures)
  - Authorization/access control issues (5 failures)
  - View/template rendering issues (4 failures)  
  - Form validation display issues (3 failures)

- **ProcessedPdfsControllerTest** (11 failures)
  - PDF generation errors (4 failures)
  - Template variable handling (3 failures)
  - View/content display issues (4 failures)

- **ApplicationControllerTest** (1 failure)
  - Authentication handling issue

### 2. **Integration Tests** (23 failures total)
- **PdfGenerationFlowTest** (8 failures)
  - PDF generation workflow failures
  - Authentication/authorization issues
  - Error handling problems

- **AuthenticationFlowTest** (7 failures)
  - Login/authentication flow issues
  - Password reset problems
  - User registration validation

- **DataSourceIntegrationTest** (6 failures)
  - Job processing issues
  - Data refresh problems
  - API error handling

- **PdfGenerationTest** (2 failures)
  - Grover PDF generation errors

### 3. **Services** (18 failures total)
- **BaseApiServiceTest** (8 failures, 1 error)
  - API request handling issues
  - Error handling problems
  - Result structure issues

- **StockServiceTest** (6 failures, 1 error)
  - API response parsing issues
  - Error message formatting
  - Network error handling

- **NewsServiceTest** (3 failures)
  - Error message format issues
  - JSON parsing error handling

- **LocationServiceTest** (3 failures)
  - Similar error message format issues

### 4. **Jobs** (7 failures total)
- **FetchDataSourceJobTest** (5 failures)
  - WebMock stubbing issues
  - Network error simulation problems

- **RefreshAllDataSourcesJobTest** (2 failures)
  - Job enqueueing count mismatches

### 5. **Models** (1 failure total)
- **ProcessedPdfTest** (1 failure)
  - Ordering/sorting issue

## Common Patterns:
1. **Error message format mismatches** - Many tests expect specific error message formats that don't match actual output
2. **WebMock stubbing issues** - API tests are hitting real endpoints instead of mocked ones
3. **View/template rendering** - Expected content not appearing in rendered views
4. **Authentication/authorization** - Access control not working as expected
5. **Job enqueueing counts** - Mismatches between expected and actual job counts

## Most Critical Areas:
1. PDF generation and processing workflow
2. API service error handling and stubbing
3. Authentication and authorization flows
4. View rendering and content display