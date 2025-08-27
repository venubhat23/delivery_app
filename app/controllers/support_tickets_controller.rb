class SupportTicketsController < ApplicationController
  before_action :set_support_ticket, only: [:show, :edit, :update, :destroy, :resolve, :reopen]
  before_action :authenticate_user!

  def index
    @support_tickets = SupportTicket.includes(:customer).recent
    @support_tickets = @support_tickets.where(status: params[:status]) if params[:status].present?
    @support_tickets = @support_tickets.where(channel: params[:channel]) if params[:channel].present?
    @support_tickets = @support_tickets.page(params[:page])
  end

  def show
  end

  def new
    @support_ticket = SupportTicket.new
  end

  def edit
  end

  def create
    @support_ticket = SupportTicket.new(support_ticket_params)

    if @support_ticket.save
      redirect_to support_tickets_path, notice: 'Support ticket was successfully created.'
    else
      render :new
    end
  end

  def update
    if @support_ticket.update(support_ticket_params)
      redirect_to support_tickets_path, notice: 'Support ticket was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @support_ticket.destroy
    redirect_to support_tickets_path, notice: 'Support ticket was successfully deleted.'
  end

  def resolve
    @support_ticket.resolve!
    redirect_to support_tickets_path, notice: 'Ticket was resolved.'
  end

  def reopen
    @support_ticket.reopen!
    redirect_to support_tickets_path, notice: 'Ticket was reopened.'
  end

  private

  def set_support_ticket
    @support_ticket = SupportTicket.find(params[:id])
  end

  def support_ticket_params
    params.require(:support_ticket).permit(:customer_id, :subject, :message, :channel, :status, :priority, :assigned_to)
  end
end