# Date format configurations for DD.MM.YYYY format
Date::DATE_FORMATS[:default] = "%d.%m.%Y"
Date::DATE_FORMATS[:short] = "%d.%m.%Y"
Date::DATE_FORMATS[:long] = "%d %B %Y"
Date::DATE_FORMATS[:month_year] = "%B %Y"

Time::DATE_FORMATS[:default] = "%d.%m.%Y %H:%M"
Time::DATE_FORMATS[:short] = "%d.%m.%Y %H:%M"
Time::DATE_FORMATS[:long] = "%d %B %Y %H:%M"
Time::DATE_FORMATS[:time_only] = "%H:%M"

# Set default locale
I18n.default_locale = :en