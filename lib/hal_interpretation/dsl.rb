module HalInterpretation
  module Dsl
    # Declare the class of models this interpreter builds.
    def item_class(klass)
      define_method(:item_class) do
        klass
      end
    end

    # Declare that an attribute should be extract from the HAL
    # document.
    #
    # attr_name - name of attribute on model to extract
    #
    # opts - hash of named arguments to method
    #
    #   :from - JSON path from which to get the value for
    #     attribute. Default: "/#{attr_name}".
    #
    #   :with - Callable that can extract the value when
    #     passed a HalClient::Representation of the item.
    #
    #   :coercion - callable with which the raw value should be
    #     transformed before being stored.
    def extract(attr_name, opts={})
      extractor_opts = {
        attr: attr_name,
        location: opts.fetch(:from) { "/#{attr_name}" }
      }
      extractor_opts[:extraction_proc] = opts.fetch(:with) if opts[:with]
      extractor_opts[:coercion] = opts[:coercion] if opts[:coercion]

      extractors << Extractor.new(extractor_opts)
    end

    # Declare that an attribute should be extracted the HAL document's
    # links (or embeddeds) where only one instance of that link type
    # is legal.
    #
    # attr_name - name of the attribute on the model to extract
    #
    # opts - hash of named arguments
    #
    #  :rel - rel of link to extract. Default: attr_name
    #
    #  :coercion - callable with which the raw URL should transformed
    #  before being stored in the model
    #
    # Examples
    #
    #     extract_link :author_website,
    #                  rel: "http://xmlns.com/foaf/0.1/homepage"
    #
    # extracts the target of the `.../homepage` link and stores in the
    # `author_website` attribute of the model.
    #
    #     extract_link :parent, rel: "up",
    #                   coercion: ->(url) {
    #                     Blog.find id_from_url(u)
    #                   }
    #
    # looks up the blog pointed to by the `up` link and stores that
    # model instance in the `parent` association of the model we are
    # interpreting.
    def extract_link(attr_name, opts={})
      orig_coercion = opts[:coercion] || IDENTITY
      adjusted_opts = opts.merge coercion: ->(urls) {
        fail "Too many instances (expected exactly 1, found #{urls.count})" if
          urls.count > 1

        instance_exec urls.first, &orig_coercion
      }

      extract_links attr_name, adjusted_opts
    end

    # Declare that an attribute should be extracted the HAL document's
    # links (or embeddeds).
    #
    # attr_name - name of the attribute on the model to extract
    #
    # opts - hash of named arguments
    #
    #  :rel - rel of link to extract. Default: attr_name
    #
    #  :coercion - callable with which the raw URL should transformed
    #  before being stored in the model
    #
    # Examples
    #
    #     extract_links :author_websites,
    #                   rel: "http://xmlns.com/foaf/0.1/homepage"
    #
    # extracts the targets of the `.../homepage` link and stores in the
    # `author_websites` attribute of the model.
    #
    #     extract_links :parents, rel: "up",
    #                   coercion: ->(urls) {
    #                     urls.map { |u| Blog.find id_from_url(u) }
    #                   }
    #
    # looks up the blogs pointed to by the `up` links and stores that
    # collection of model instances in the `parents` association of
    # the model we are interpreting.
    def extract_links(attr_name, opts={})
      rel = opts.fetch(:rel) { attr_name }.to_s
      path = "/_links/" + json_path_escape(rel)

      stringify_href = ->(string_or_uri_tmpl) {
        if string_or_uri_tmpl.respond_to? :pattern
          string_or_uri_tmpl.pattern
        else
          string_or_uri_tmpl.to_str
        end
      }

      extract attr_name, from: path,
              with: ->(r){ r.raw_related_hrefs(rel){[]}.map &stringify_href },
              coercion: opts[:coercion]
    end


    protected

    def json_path_escape(rel)
      rel.gsub('~', '~0').gsub('/', '~1')
    end

    IDENTITY = ->(o) { o }
  end
end
