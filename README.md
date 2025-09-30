# Lavela Health Backend Take-Home

Welcome! This repository is the starting point for a short backend exercise. The goal is to ingest third-party availability data and expose appointment booking endpoints on top of a small scheduling domain.

## Implementation Status 

This implementation includes:

1. **Data Models**: Complete ActiveRecord models with associations and validations
    - `Client` - People booking appointments
    - `Provider` - Healthcare providers offering care
    - `Availability` - Time windows when providers are available
    - `Appointment` - Scheduled appointments connecting clients to providers

2. **API Endpoints**: Fully functional REST endpoints
    - `GET /providers/:provider_id/availabilities?from=...&to=...` - Returns available time slots
    - `POST /appointments` - Books new appointments with conflict validation
    - `DELETE /appointments/:id` - Soft-cancels appointments

3. **Business Logic**: Robust scheduling system with
    - Availability window management
    - Appointment conflict detection
    - Time slot calculations
    - Data integrity validations

4. **Testing**: Comprehensive RSpec test suite


## Prerequisites

- Ruby 3.4.3 (see `.ruby-version`)
- Bundler (`gem install bundler` if it is missing)
- SQLite (bundled with macOS, no extra setup required)

## Rules
- Please do not use LLM coding tools (Codex, Claude Code, Cursor, etc) to complete this exercise. Looking things up from the web or using ChatGPT as a reference is fine!

## Getting Started

1. Install dependencies: `bundle install`
2. Create your database schema: `bin/rails db:setup`
3. Run the test suite: `rspec` or `bundle exec rspec`

## Testing

This application uses **RSpec** as the testing framework with **FactoryBot** for test data generation:

- **Run all tests**: `rspec`
- **Run specific categories**: 
  - `rspec spec/models/` - Model validations and business logic
  - `rspec spec/requests/` - API endpoints and controllers  
  - `rspec spec/features/` - Integration workflows
- **Test coverage**: 145+ examples covering models, controllers, and end-to-end flows

## API Testing with Postman

This repository includes a complete **Postman collection** and **environment** for testing all API endpoints interactively.

### Setup Instructions

1. **Import the Collection**:
   - Open Postman
   - Click **Import** → **Upload Files**
   - Select `postman_collection.json` from the project root
   - The collection "Lavela Health Scheduling API" will be imported

2. **Import the Environment**:
   - In Postman, go to **Environments** → **Import**
   - Select `postman_environment.json` from the project root
   - Select the "Lavela Health Scheduling - Development" environment

3. **Start the Rails Server**:
   ```bash
   bin/rails server
   # Server runs on http://localhost:3000
   ```

4. **Seed the Database** (if needed):
   ```bash
   bin/rails db:seed #(Assuming you have already run bin/rails db:setup)
   # Creates test providers, clients, and availability data
   ```

### Available API Endpoints

The Postman collection includes comprehensive tests for all endpoints:

#### 🏥 Health Check
- **GET** `/up` - Verify the Rails application is running

#### 📅 Provider Availabilities  
- **GET** `/providers/:provider_id/availabilities?from=<ISO8601>&to=<ISO8601>`
  - Get available time slots for a provider within a date range
  - **Parameters**: 
    - `provider_id` - Provider ID (1, 2, etc.)
    - `from` - Start time (ISO8601 format, e.g., `2025-10-06T00:00:00Z`)
    - `to` - End time (ISO8601 format, e.g., `2025-10-06T23:59:59Z`)

#### 📋 Appointment Management
- **POST** `/appointments` - Create new appointment
  - **Body**:
    ```json
    {
      "client_id": 1,
      "provider_id": 1,
      "starts_at": "2025-10-06T13:00:00Z",
      "ends_at": "2025-10-06T13:30:00Z"
    }
    ```
- **DELETE** `/appointments/:id` - Cancel appointment (soft delete)

### Test Scenarios Included

The collection includes **30+ test scenarios** organized by functionality:

#### ✅ **Availability Tests**
- Current week availability
- Next week availability  
- Single day queries
- Different providers
- Error handling (invalid provider, missing parameters)

#### ✅ **Appointment Creation Tests**
- Valid appointment booking
- Appointments with explicit duration
- Different client/provider combinations
- **Error scenarios**:
  - Missing required parameters
  - Invalid time ranges (end before start)
  - Past appointment times
  - No availability window
  - Conflicting appointments
  - Non-existent clients/providers

#### ✅ **Appointment Cancellation Tests**
- Valid cancellation
- Non-existent appointment handling

#### ✅ **Integration Workflow Tests**
- Complete booking flow: Check availability → Book appointment → Verify updated availability

### Environment Variables

The environment includes pre-configured variables:

```json
{
  "base_url": "http://localhost:3000",
  "provider_id": "1",
  "client_id": "1", 
  "test_start_time": "2025-10-06T13:00:00Z",
  "test_end_time": "2025-10-06T13:30:00Z"
}
```

You can modify these variables or create additional environments for different testing scenarios.

### Running the Tests

1. **Sequential Testing**: Run requests individually to understand each endpoint
2. **Batch Testing**: Use Postman's Collection Runner to execute all tests automatically
3. **Integration Testing**: Follow the "Integration Tests" folder for complete workflows

### Expected Response Formats

#### Availability Response
```json
{
  "provider_id": 1,
  "available_slots": [
    {
      "starts_at": "2025-10-06T13:00:00Z",
      "ends_at": "2025-10-06T14:00:00Z",
      "duration_minutes": 60
    }
  ]
}
```

#### Appointment Response
```json
{
  "id": 1,
  "client_id": 1,
  "provider_id": 1,
  "starts_at": "2025-10-06T13:00:00Z",
  "ends_at": "2025-10-06T13:30:00Z",
  "status": "scheduled"
}
```