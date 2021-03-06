require 'puppet'
require 'puppet/face'
require 'awesome_print'
require 'yajl'

Puppet::Face.define(:minicat, '0.0.1') do

    copyright "Apple Inc", 2012
    license "Apache 2.0"

    summary "Make a mini-catalog, to view data-driven template output"
    description <<-EOT
    This subcommand eases the debugging of external-data-driven Puppet templates by fetching the External Node 
    Classifier output from the exec terminus but modifying the list of classes to a user-specified subset.
    EOT

    action 'compile' do
        summary "Compile and display a catalog locally, driven by the node classifier"
        description <<-EOT
      Similar to puppet apply, but with the option to (a) pretend to be a different node and
      (b) modify the list of classes returned by the node classifier
        EOT

        option "--node NODENAME" do
            summary "Fetch data from the ENC as if we were this node"
            required
        end
        option "--classlist puppet::class1,puppet::class2" do
            summary "Comma-separated list of classes to include in the compiled catalog (defaults to ENC list if omitted)"
        end
        option "--contentonly" do
            summary "Display File resource content in a screen-friendly way, ignoring non-File resources"
        end
        option "--sorted" do
            summary "Display most catalog data sorted"
        end
        option "--filename PATH" do
            summary "Show file with name <filename>"
        end

        when_invoked do |options|
            Puppet.notice "looking up #{options[:node]}..."
            node = Puppet::Node.indirection.find(options[:node])
            if node
                if options[:classlist]
                    node.classes = options[:classlist].split(',')
                end
            else
                raise "Couldn't find node #{options[:node]}"
            end

            catalog = Puppet::Resource::Catalog.indirection.find(node.name, :use_node => node)
            c = Yajl::Parser.parse(catalog.to_pson)

            if options[:contentonly]
                c["data"]["resources"].each do |res|
                    content = res["parameters"].delete("content") if res["parameters"]
                    if res["type"] == "File" && content
                        filename = res["parameters"]["path"] || res["title"]
                        if options[:filename] and !filename.include? options[:filename]
                            next
                        end
                        ap res["file"]
                        ap filename
                        puts content
                        print "----------------------------------\n\n"

                    end
                end

            elsif options[:sorted]

                # build up a sorted data structure

                ## resources
                ## resources are sorted by the attributes (we believe) will always
                ## be present in any valid resource declaration: title and class. This
                ## is intended to guarantee sort order for the purpose of comparison
                resources = c["data"]["resources"].sort { |a, b|
                    akey = "#{a['title']}#{a['type']}"
                    bkey = "#{b['title']}#{b['type']}"
                    akey <=> bkey
                }

                ## targets
                targets = c["data"]["edges"].sort_by {
                    |a| "#{a['target']}#{a['source']}"
                }

                ## classes
                classes = c["data"]["classes"].sort

                ## tags
                tags = c["data"]["tags"].sort


                print "\n###############   resources  ###############################\n"
                ap resources

                print "\n###############   targets    ###############################\n"
                ap targets

                print "\n###############   classes    ###############################\n"
                ap classes

                print "\n###############   tags       ###############################\n"
                ap tags

                print "\n"
            else
                ap c
                Puppet.notice "kthxbye"
            end

        end
    end

end
