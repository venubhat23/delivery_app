class TempFilesController < ApplicationController
  def show
    filename = params[:filename]
    file_path = Rails.root.join('tmp', filename)
    
    if File.exist?(file_path)
      send_file file_path, type: 'application/pdf', disposition: 'inline'
    else
      head :not_found
    end
  end
end