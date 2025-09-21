module Api
  module V1
    class InvoicesController < BaseController
      # GET /api/v1/invoices
      # Optional params: status, start_date, end_date
      def index
        invoices = scoped_invoices
        invoices = invoices.where(status: params[:status]) if params[:status].present?
        if params[:start_date].present? && params[:end_date].present?
          begin
            from = Date.parse(params[:start_date])
            to = Date.parse(params[:end_date])
            invoices = invoices.where(invoice_date: from..to)
          rescue ArgumentError
            return render json: { error: 'Invalid date format' }, status: :bad_request
          end
        end

        invoices = invoices.includes(:customer).order(invoice_date: :desc, id: :desc)

        summary = build_summary(invoices)

        render json: {
          invoices: invoices.as_json(only: [:id, :invoice_number, :invoice_type, :status, :invoice_date, :due_date, :total_amount, :paid_at], include: { customer: { only: [:id, :name] } }),
          summary: summary
        }
      end

      private

      def scoped_invoices
        if current_user.is_a?(User)
          Invoice.joins(:customer).where(customers: { user_id: current_user.id })
        elsif current_user.is_a?(Customer)
          Invoice.where(customer_id: current_user.id)
        else
          Invoice.none
        end
      end

      def build_summary(relation)
        relation_without_order = relation.except(:order)
        counts_by_status = relation_without_order.group(:status).count
        total_amount = relation_without_order.sum(:total_amount).to_f
        {
          total_count: relation_without_order.count,
          total_amount: total_amount,
          pending_count: counts_by_status['pending'] || 0,
          paid_count: counts_by_status['paid'] || 0,
          overdue_count: counts_by_status['overdue'] || 0,
          cancelled_count: counts_by_status['cancelled'] || 0
        }
      end
    end
  end
end