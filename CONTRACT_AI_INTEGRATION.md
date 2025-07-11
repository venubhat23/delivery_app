# Contract AI Integration System

This system automatically processes contract descriptions using ChatGPT and forwards the responses to the Marketincer API.

## Features

- **Automatic AI Processing**: When a user creates a contract with a description, it's automatically sent to ChatGPT for analysis
- **API Integration**: The AI response is automatically forwarded to the Marketincer API endpoint
- **Status Tracking**: Track the processing status of each contract (pending, processing, completed, failed)
- **Web Interface**: User-friendly interface to create, view, and manage contracts
- **API Endpoint**: RESTful API for external integrations

## How It Works

1. **User Input**: User enters a contract description through the web interface
2. **Contract Creation**: System creates a new contract record with status "pending"
3. **AI Processing**: Contract description is sent to ChatGPT API for analysis
4. **API Forward**: ChatGPT response is automatically sent to Marketincer API
5. **Status Update**: Contract status is updated to "completed" or "failed"
6. **User Notification**: User can view the AI response and processing status

## Setup Instructions

### 1. Environment Variables

Add these environment variables to your system:

```bash
# OpenAI API Key (required for ChatGPT integration)
export OPENAI_API_KEY="your-openai-api-key-here"

# Optional: Configure API endpoints if they change
export CHATGPT_API_URL="https://api.openai.com/v1/chat/completions"
export MARKETINCER_API_URL="https://api.marketincer.com/api/v1/contracts/generate"
```

### 2. Database Migration

Run the database migration to create the contracts table:

```bash
rails db:migrate
```

### 3. Install Dependencies

Make sure these gems are installed:

```ruby
gem 'ruby-openai'  # For ChatGPT integration
gem 'httparty'     # For HTTP requests
```

## Usage

### Web Interface

1. Navigate to `/contracts` to view all contracts
2. Click "New Contract" to create a new contract
3. Enter your contract description and click "Create Contract"
4. The system will automatically process the contract with AI
5. View the AI response and processing status on the contract details page

### API Usage

Create a contract via API:

```bash
curl -X POST http://your-domain.com/contracts/api_create \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {
      "description": "Your contract description here"
    }
  }'
```

Response:
```json
{
  "status": "success",
  "contract": {
    "id": 1,
    "description": "Your contract description here",
    "ai_response": "AI generated response...",
    "status": "completed",
    "created_at": "2023-01-01T00:00:00Z"
  }
}
```

## API Endpoints

### Contracts
- `GET /contracts` - List all contracts
- `GET /contracts/:id` - View specific contract
- `POST /contracts` - Create new contract (web form)
- `POST /contracts/api_create` - Create new contract (API)
- `PUT /contracts/:id` - Update contract
- `DELETE /contracts/:id` - Delete contract
- `PATCH /contracts/:id/process_with_ai` - Manually trigger AI processing

## Data Flow

```
User Input → Contract Creation → ChatGPT API → AI Response → Marketincer API → Status Update
```

## Files Structure

```
app/
├── controllers/
│   └── contracts_controller.rb    # Web interface and API endpoints
├── models/
│   └── contract.rb               # Contract model with validations
├── service/
│   └── contract_ai_service.rb    # AI integration service
├── views/
│   └── contracts/
│       ├── index.html.erb        # List contracts
│       ├── show.html.erb         # View contract details
│       ├── new.html.erb          # Create new contract
│       └── edit.html.erb         # Edit contract
└── db/
    └── migrate/
        └── create_contracts.rb   # Database migration
```

## Error Handling

The system includes comprehensive error handling:

- **ChatGPT API Errors**: Logged and contract marked as "failed"
- **Marketincer API Errors**: Logged and contract marked as "failed"
- **Network Errors**: Handled gracefully with retry capability
- **Validation Errors**: User-friendly error messages displayed

## Security Considerations

- API keys are stored as environment variables
- User authentication required for all contract operations
- Input validation to prevent malicious content
- Rate limiting recommended for API endpoints

## Customization

### Modify AI Prompt

Edit the system prompt in `app/service/contract_ai_service.rb`:

```ruby
{
  role: 'system',
  content: 'Your custom AI prompt here...'
}
```

### Change API Endpoints

Update the constants in `ContractAiService`:

```ruby
CHATGPT_API_URL = 'your-custom-chatgpt-url'
MARKETINCER_API_URL = 'your-custom-marketincer-url'
```

## Monitoring

Monitor the system by checking:
- Contract status distribution
- Failed processing rates
- API response times
- Error logs in Rails logs

## Support

For technical support or feature requests, refer to the main application documentation or contact the development team.