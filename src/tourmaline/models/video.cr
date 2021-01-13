module Tourmaline
  class Video
    include JSON::Serializable
    include Tourmaline::Model

    getter file_id : String

    getter file_unique_id : String

    getter width : Int32

    getter height : Int32

    getter duration : Int32

    getter thumb : PhotoSize?

    getter file_name : String?

    getter mime_type : String?

    getter file_size : Int32?
  end
end
