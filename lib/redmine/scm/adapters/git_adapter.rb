# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine/scm/adapters/abstract_adapter'
require 'grit'



module Redmine
  module Scm
    module Adapters    
      class GitAdapter < AbstractAdapter
        attr_accessor :repo

        # Git executable name
        GIT_BIN = "git"

        def initialize(*args)
          args[1] = args[0]
          super(*args)

          begin
            @repo = Grit::Repo.new(url, :is_bare => true)
          rescue
            Rails::logger.error "Repository could not be created"
          end
        end

        def info
          begin
            Info.new(:root_url => url, :lastrev => @repo.log('all', nil, :n => 1).first.to_revision)
          rescue
            nil
          end
        end

        def branches
          return nil if @repo.branches.length == 0
          @repo.branches.collect{|b| b.name}.sort!
        end

        def tags 
          return nil if @repo.tags.length == 0
          @repo.tags.collect{|t| t.name}.sort!
        end

        def default_branch
          begin
            @repo.default_branch
          rescue
            nil
          end
        end
        
        def entries(path=nil, identifier=nil)
          return nil if repo.nil?
          path = nil if path.empty?

          entries = Entries.new
          
          tree = repo.log(identifier, path, :n => 1).first.tree 
          tree = tree / path if path

          tree.contents.each do |file|
            file_path = path ? "#{path}/#{file.name}" : file.name
            commit = repo.log(identifier, file_path, :n => 1).first

            entries << Entry.new({
              :name => file.name,
              :path => file_path,
              :kind => file.class == Grit::Blob ? 'file' : 'dir',
              :size => file.respond_to?('size') ? file.size : nil,
              :lastrev => commit.to_revision
            })
          end

          entries.sort_by_name
        end

        def revisions(path, identifier_from, identifier_to, options={})
          revisions = Revisions.new
          cmd = "#{GIT_BIN} --git-dir #{target('')} log -M -C --all --raw --date=iso --pretty=fuller --no-merges"
          cmd << " --reverse" if options[:reverse]
          cmd << " -n #{options[:limit].to_i} " if (!options.nil?) && options[:limit]
          cmd << " #{shell_quote(identifier_from + '..')} " if identifier_from
          cmd << " #{shell_quote identifier_to} " if identifier_to
          shellout(cmd) do |io|
            files=[]
            changeset = {}
            parsing_descr = 0  #0: not parsing desc or files, 1: parsing desc, 2: parsing files
            revno = 1

            io.each_line do |line|
              if line =~ /^commit ([0-9a-f]{40})$/
                key = "commit"
                value = $1
                if (parsing_descr == 1 || parsing_descr == 2)
                  parsing_descr = 0
                  revision = Revision.new({:identifier => changeset[:commit],
                                           :scmid => changeset[:commit],
                                           :author => changeset[:author],
                                           :time => Time.parse(changeset[:date]),
                                           :message => changeset[:description],
                                           :paths => files
                                          })
                  if block_given?
                    yield revision
                  else
                    revisions << revision
                  end
                  changeset = {}
                  files = []
                  revno = revno + 1
                end
                changeset[:commit] = $1
              elsif (parsing_descr == 0) && line =~ /^(\w+):\s*(.*)$/
                key = $1
                value = $2
                if key == "Author"
                  changeset[:author] = value
                elsif key == "CommitDate"
                  changeset[:date] = value
                end
              elsif (parsing_descr == 0) && line.chomp.to_s == ""
                parsing_descr = 1
                changeset[:description] = ""
              elsif (parsing_descr == 1 || parsing_descr == 2) && line =~ /^:\d+\s+\d+\s+[0-9a-f.]+\s+[0-9a-f.]+\s+(\w)\s+(.+)$/
                parsing_descr = 2
                fileaction = $1
                filepath = $2
                files << {:action => fileaction, :path => filepath}
              elsif (parsing_descr == 1) && line.chomp.to_s == ""
                parsing_descr = 2
              elsif (parsing_descr == 1)
                changeset[:description] << line[4..-1]
              end
            end 

            if changeset[:commit]
              revision = Revision.new({:identifier => changeset[:commit],
                                       :scmid => changeset[:commit],
                                       :author => changeset[:author],
                                       :time => Time.parse(changeset[:date]),
                                       :message => changeset[:description],
                                       :paths => files
                                      })
              if block_given?
                yield revision
              else
                revisions << revision
              end
            end
          end

          return nil if $? && $?.exitstatus != 0
          revisions
        end

        def diff(path, identifier_from, identifier_to=nil)
          path ||= ''
          if !identifier_to
            identifier_to = nil
          end
          
          cmd = "#{GIT_BIN} --git-dir #{target('')} show #{shell_quote identifier_from}" if identifier_to.nil?
          cmd = "#{GIT_BIN} --git-dir #{target('')} diff #{shell_quote identifier_to} #{shell_quote identifier_from}" if !identifier_to.nil?
          cmd << " -- #{shell_quote path}" unless path.empty?
          diff = []
          shellout(cmd) do |io|
            io.each_line do |line|
              diff << line
            end
          end
          return nil if $? && $?.exitstatus != 0
          diff
        end
        
        def annotate(path, identifier=nil)
          identifier = 'HEAD' if identifier.blank?
          cmd = "#{GIT_BIN} --git-dir #{target('')} blame -l #{shell_quote identifier} -- #{shell_quote path}"
          blame = Annotate.new
          content = nil
          shellout(cmd) { |io| io.binmode; content = io.read }
          return nil if $? && $?.exitstatus != 0
          # git annotates binary files
          return nil if content.is_binary_data?
          content.split("\n").each do |line|
            next unless line =~ /([0-9a-f]{39,40})\s\((\w*)[^\)]*\)(.*)/
            blame.add_line($3.rstrip, Revision.new(:identifier => $1, :author => $2.strip))
          end
          blame
        end
        
        def cat(path, identifier=nil)
          if identifier.nil?
            identifier = 'HEAD'
          end
          cmd = "#{GIT_BIN} --git-dir #{target('')} show #{shell_quote(identifier + ':' + path)}"
          cat = nil
          shellout(cmd) do |io|
            io.binmode
            cat = io.read
          end
          return nil if $? && $?.exitstatus != 0
          cat
        end
      end
    end
  end
end

module Grit
  class Repo
    def log(commit = 'all', path = nil, options = {})
      default_options = {:pretty => "raw", "no-merges" => true}
      commit = default_branch if commit.nil?

      if commit == 'all'
        commit = default_branch 
        default_options.merge!(:all => true)
      end

      actual_options  = default_options.merge(options)
      arg = path ? [commit, '--', path] : [commit]
      commits = self.git.log(actual_options, *arg)
      Commit.list_from_string(self, commits)
    end

    def default_branch
      if branches.map{|h| h.name}.include?('master') 
        'master'
      else
        branches.first.name
      end
    end
  end

  class Diff
    def action
      return 'A' if new_file
      return 'D' if deleted_file
      return 'M'
    end

    def path
      return a_path if a_path
      return b_path if b_path
    end
  end

  class Commit
    def to_revision
      Redmine::Scm::Adapters::Revision.new({
        :identifier => id,
        :scmid => id,
        :author => "#{author.name} <#{author.email}>",
        :time => committed_date,
        :message => message
      })
    end
  end
end
