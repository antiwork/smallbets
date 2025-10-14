module TimeHelper
  def local_datetime_tag(datetime, style: :time, **attributes)
    tag.time **attributes, datetime: datetime.iso8601, data: { local_time_target: style.to_s.gsub('_', '') }
  end
end
