module DashboardsHelper
  def counter_caption(result)
    case result.state
    when :ongoing then "incident in progress"
    when :counting then "#{"day".pluralize(result.days)} since last incident"
    else result.infinite? ? "no incidents on record" : "#{"day".pluralize(result.days)} since tracking started, no incidents"
    end
  end
end
