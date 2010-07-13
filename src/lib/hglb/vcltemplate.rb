require 'erb'

module HGLB

  class VCLTemplate

    def initialize(config, state, clustername)
      @config      = config
      @state       = state
      @clustername = clustername
    end

    def generate_config(opts = {})
      template = ERB.new(File.read(@config.cluster_template(@clustername)))
      template.result(binding)
    end

    def backends_stanza
      @config.cluster_backends(@clustername).sort.map do |be|
        <<EOF
backend #{be} {
  .host = "#{@config.backend_ip(be)}";
  .port = "#{@config.backend_port(be)}";
  #{@config.backend_options(be).gsub("\n", "\n  ")}
}
EOF
      end.join("")
    end

    def directors_stanza
      @config.cluster_directors(@clustername).sort.map do |d|
        <<EOF
director #{d} random {
#{directors_backends_stanza(d)}
}
EOF
      end.join("")
    end

    def directors_backends_stanza(director)
      @config.director_backends(director).map do |be|
        if @state.backend_enabled?(be)
          "  { .backend = #{be}; .weight = 10; }"
        end
      end.join("\n")
    end

    def directed_server_stanza( director, prettyspacing=2 )
      indent = " "*prettyspacing
      @config.director_backends(director).sort.map do |be|
        <<EOF.strip
if (req.url ~ "\\?.*server=#{@config.backend_host(be)}.*") {
  set req.backend = #{be};
  return (pass);
}
EOF
      end.join("\n").gsub(/\n/, "\n#{indent}")
    end

  end

end

# Modeline
# vim:ts=2:et:ai:sw=2
