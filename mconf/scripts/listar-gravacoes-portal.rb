# coding: utf-8
require 'csv'

# busca todas as gravações mais antigas que "hoje menos esse período"
period = 90.days
# para pegar todas as gravações, usar:
# period = -1.days

csv_config = {
  col_sep: ",",
  row_sep: "\n",
  encoding: 'ISO-8859-1'
}
s = CSV.generate(csv_config) do |csv|
  # colunas:
  # Data da gravação, ID da gravação, ID da reunião, tipo (usuário/comunidade),
  # instituição, nome do dono, email(s) do(s) dono(s), tamanho da gravação (MBytes),
  # duração da gravação (hh:mm:ss), publicada ou não
  columns = [
    :date, :record_id, :meeting_id, :institution, :room_type, :owner_name,
    :owner_email, :size_mb, :duration, :published
  ]
  csv << columns

  BigbluebuttonRecording.where("created_at <= ?", DateTime.now.beginning_of_day - period).find_each do |rec|
    mails = []
    institution = nil
    type = nil
    name = nil
    room_id = nil
    length = nil

    room = rec.room
    if room.present?
      room_id = room.meetingid
      owner = room.owner
      if owner.present?
        institution = owner.institution
        if owner.is_a?(Space)
          mails = owner.admins.pluck(:email)
          type = "Space"
          name = owner.name
        elsif owner.is_a?(User)
          mails = [owner.email]
          type = "User"
          name = owner.name
        end
      end
    end

    if rec.playback_formats.count > 0
      t = rec.playback_formats[0].length_in_secs
      length = Time.at(t).utc.strftime("%H:%M:%S")
    end

    row = [
      rec.created_at.utc,
      rec.recordid,
      room_id,
      institution.present? ? institution.name : nil,
      type,
      name,
      mails.join(";"),
      rec.size.present? ? (rec.size / (1000.0 * 1000.0)) : nil, # MB
      length,
      rec.published?
    ]
    csv << row
    puts row.join(", ")
  end
end
File.write('/tmp/recordings.csv', s)

puts 'File /tmp/recordings.csv saved.'
