module ApplicationHelper
  # Existing helper methods...

  # Enhanced form helpers for searchable dropdowns and date pickers
  def searchable_select(form, field, options, html_options = {})
    searchable_options = {
      url: html_options.delete(:search_url),
      placeholder: html_options.delete(:placeholder) || "Select an option...",
      allow_clear: html_options.delete(:allow_clear) != false,
      minimum_input_length: html_options.delete(:minimum_input_length) || 0
    }

    # Remove nil values from searchable_options
    searchable_options.compact!

    # Build data attributes for Stimulus controller
    data_attributes = {
      controller: "searchable-select",
      "searchable-select-placeholder-value" => searchable_options[:placeholder],
      "searchable-select-allow-clear-value" => searchable_options[:allow_clear]
    }

    data_attributes["searchable-select-url-value"] = searchable_options[:url] if searchable_options[:url]
    data_attributes["searchable-select-minimum-input-length-value"] = searchable_options[:minimum_input_length] if searchable_options[:minimum_input_length] > 0

    # Merge with existing data attributes
    html_options[:data] ||= {}
    html_options[:data].merge!("searchable-select-target" => "select")

    content_tag :div, data: data_attributes do
      form.select(field, options, {}, html_options)
    end
  end

  def enhanced_date_picker(form, field, html_options = {})
    date_options = {
      mode: html_options.delete(:mode) || "single",
      min_date: html_options.delete(:min_date),
      max_date: html_options.delete(:max_date),
      enable_time: html_options.delete(:enable_time) || false,
      date_format: html_options.delete(:date_format),
      alt_format: html_options.delete(:alt_format),
      default_date: html_options.delete(:default_date),
      disable: html_options.delete(:disable),
      enable: html_options.delete(:enable),
      inline: html_options.delete(:inline) || false
    }

    # Remove nil values from date_options
    date_options.compact!

    # Build data attributes for Stimulus controller
    data_attributes = {
      controller: "date-picker"
    }

    date_options.each do |key, value|
      data_attributes["date-picker-#{key.to_s.gsub('_', '-')}-value"] = value
    end

    # Merge with existing data attributes
    html_options[:data] ||= {}
    html_options[:data].merge!("date-picker-target" => "input")

    content_tag :div, data: data_attributes do
      if html_options.delete(:type) == :datetime
        form.datetime_local_field(field, html_options)
      else
        form.date_field(field, html_options)
      end
    end
  end

  def enhanced_form_group(label_text, options = {}, &block)
    css_classes = ["form-group-enhanced"]
    css_classes << options[:class] if options[:class]

    content_tag :div, class: css_classes.join(" ") do
      content = ""
      if label_text
        content += content_tag(:label, label_text, class: "form-label")
      end
      content += capture(&block) if block_given?
      content.html_safe
    end
  end

  def status_badge(status, options = {})
    badge_classes = case status.to_s.downcase
    when 'pending'
      'badge bg-warning text-dark'
    when 'in_progress', 'active'
      'badge bg-info text-white'
    when 'completed', 'success'
      'badge bg-success text-white'
    when 'cancelled', 'failed'
      'badge bg-danger text-white'
    when 'draft'
      'badge bg-secondary text-white'
    else
      'badge bg-light text-dark'
    end

    badge_classes += " #{options[:class]}" if options[:class]

    content_tag :span, status.humanize, class: badge_classes
  end

  def loading_spinner(options = {})
    size = options[:size] || 'normal'
    text = options[:text] || 'Loading...'
    
    spinner_class = case size
    when 'small'
      'spinner-border spinner-border-sm'
    when 'large'
      'spinner-border spinner-border-lg'
    else
      'spinner-border'
    end

    content_tag :div, class: "d-flex align-items-center" do
      content = content_tag(:div, "", class: "#{spinner_class} text-primary me-2", role: "status")
      content += content_tag(:span, text) if text
      content
    end
  end

  def enhanced_card(title, options = {}, &block)
    card_classes = ["card"]
    card_classes << options[:class] if options[:class]
    
    content_tag :div, class: card_classes.join(" ") do
      content = ""
      
      if title || options[:header]
        content += content_tag(:div, class: "card-header") do
          if title
            content_tag(:h5, title, class: "card-title mb-0")
          else
            options[:header]
          end
        end
      end
      
      content += content_tag(:div, class: "card-body") do
        capture(&block) if block_given?
      end
      
      content.html_safe
    end
  end

  def quick_action_button(text, path, options = {})
    button_class = "btn btn-sm #{options[:variant] || 'btn-outline-primary'}"
    icon = options[:icon]
    method = options[:method] || :get
    confirm = options[:confirm]

    link_options = {
      class: button_class,
      method: method
    }
    link_options[:data] = { confirm: confirm } if confirm

    link_to path, link_options do
      content = ""
      content += content_tag(:i, "", class: "#{icon} me-1") if icon
      content += text
      content.html_safe
    end
  end
end
