class ActionText::Attachment::OpengraphEmbed
  include ActiveModel::Model

  OPENGRAPH_EMBED_CONTENT_TYPE = "application/vnd.actiontext.opengraph-embed"

  class << self
    def from_node(node)
      if node["content-type"]
        if matches = node["content-type"].match(OPENGRAPH_EMBED_CONTENT_TYPE)
          attachment = new(attributes_from_node(node))
          attachment if attachment.valid?
        end
      end
    end

    private
      def attributes_from_node(node)
        {
          href: node["href"],
          url: node["url"],
          filename: node["filename"],
          description: node["caption"]
        }
      end
  end

  attr_accessor :href, :url, :filename, :description

  def caption
    description
  end

  def caption=(value)
    self.description = value
  end

  def attachable_content_type
    OPENGRAPH_EMBED_CONTENT_TYPE
  end

  def attachable_plain_text_representation(caption)
    ""
  end

  def to_partial_path
    "action_text/attachables/opengraph_embed"
  end

  def to_trix_content_attachment_partial_path
    "action_text/attachables/opengraph_embed"
  end
end
