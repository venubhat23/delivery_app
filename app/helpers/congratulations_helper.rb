module CongratulationsHelper
  def show_congratulations_modal
    content_for :congratulations_modal do
      render 'shared/congratulations'
    end
  end

  def trigger_congratulations_js
    raw <<-JS
      <script>
        document.addEventListener('DOMContentLoaded', function() {
          const congratsOverlay = document.getElementById('congratulations-overlay');
          if (congratsOverlay) {
            congratsOverlay.style.display = 'flex';
          }
        });
      </script>
    JS
  end
end