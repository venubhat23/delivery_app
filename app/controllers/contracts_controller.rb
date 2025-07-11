class ContractsController < ApplicationController
  before_action :set_contract, only: [:show, :edit, :update, :destroy, :process_with_ai]
  before_action :authenticate_user!
  
  def index
    @contracts = current_user.contracts.order(created_at: :desc)
  end
  
  def show
  end
  
  def new
    @contract = current_user.contracts.build
  end
  
  def create
    @contract = current_user.contracts.build(contract_params)
    
    if @contract.save
      # Automatically process with AI after creation
      process_with_ai_async
      redirect_to @contract, notice: 'Contract was successfully created and is being processed with AI.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @contract.update(contract_params)
      redirect_to @contract, notice: 'Contract was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @contract.destroy
    redirect_to contracts_path, notice: 'Contract was successfully deleted.'
  end
  
  def process_with_ai
    begin
      service = ContractAiService.new(@contract)
      service.process_contract
      redirect_to @contract, notice: 'Contract processed successfully with AI.'
    rescue => e
      redirect_to @contract, alert: "Error processing contract: #{e.message}"
    end
  end
  
  # API endpoint for external use
  def api_create
    @contract = current_user.contracts.build(contract_params)
    
    if @contract.save
      # Process with AI immediately
      service = ContractAiService.new(@contract)
      service.process_contract
      
      render json: {
        status: 'success',
        contract: {
          id: @contract.id,
          description: @contract.description,
          ai_response: @contract.ai_response,
          status: @contract.status,
          created_at: @contract.created_at
        }
      }
    else
      render json: {
        status: 'error',
        errors: @contract.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_contract
    @contract = current_user.contracts.find(params[:id])
  end
  
  def contract_params
    params.require(:contract).permit(:description)
  end
  
  def authenticate_user!
    # Simple authentication check - adjust based on your authentication system
    unless current_user
      redirect_to login_path, alert: 'Please log in to access contracts.'
    end
  end
  
  def process_with_ai_async
    # For now, process synchronously. In production, you'd use a background job
    ContractAiService.new(@contract).process_contract
  rescue => e
    Rails.logger.error "Error processing contract #{@contract.id}: #{e.message}"
  end
end