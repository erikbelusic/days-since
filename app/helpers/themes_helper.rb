module ThemesHelper
  # The theme for this request: the signed-in (or local) user's choice, or the
  # default theme on pages without a user such as sign-in.
  def current_theme
    Theme.find_or_default(Current.user&.theme)
  end

  # Path to a theme-specific partial, falling back to the default theme's
  # version when the current theme doesn't override it:
  #   render themed_partial("feed_card"), result: ...
  def themed_partial(name, theme: current_theme)
    if lookup_context.exists?(name, [ "themes/#{theme.key}" ], true)
      "themes/#{theme.key}/#{name}"
    else
      "themes/default/#{name}"
    end
  end
end
