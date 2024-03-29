=begin
Copyright (c) 2008, Pat Sissons
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of the DHX Software nor the names of its contributors may
      be used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end

require 'open-uri'
require 'timeout'

class Show
    attr_accessor :id, :regex, :season, :episodes, :postdlcmd, :feeds

    def initialize(main, id, regex, season, min_episode, opts)
        @logger = LogManager.Instance
        @logger.ftrace {'ENTER'}
        @main = main
        @id = id
        @regex = regex
        @season = season.to_i
        # episodes is a list of episodes that have been downloaded, we must convert each string to an int with map
        @episodes = Array.new
        min_episode.to_i.downto(1) { |i| @episodes.unshift(i.to_i) }
        if opts.nil?
            raise 'Catastrophic Failure!'
        else
            # add post download command if it exists in opts
            @postdlcmd = opts.length >= 1 ? opts.shift : []
            @postdlcmd = nil if @postdlcmd.empty?
            # build list of feeds from opts if they exist
            @feeds = opts.empty? ? nil : opts.map { |f| main.feeds[f] }.compact
        end
        @logger.ftrace {'LEAVE'}
    end

    # utility function to grab
    def conf
        ConfigFile.Instance
    end

    # check if this show this show is only part of a specific feed or feeds
    def belongs_to?(feed)
        @logger.ftrace {'ENTER'}
        @logger.debug {"Checking If Feed #{feed.id} Belongs to #{@id}"}
        ret = @feeds.nil? or @feeds.include?(feed)
        @logger.ftrace {'LEAVE'}
        ret
    end

    # perform a generic regex match on the provided string
    def rxmatch(rx, string, cs = nil)
        @logger.ftrace {'ENTER'}
        @logger.debug {"Matching '#{string}' with regex '#{rx}'"}
        ret = cs.nil? ? Regexp.new(rx, Regexp::IGNORECASE).match(string) : Regexp.new(rx).match(string)
        @logger.ftrace {'LEAVE'}
        ret
    end

    # check if the provided title is considered a new show (something that has not yet been downloaded)
    def new_show?(title)
        @logger.ftrace {'ENTER'}
        ret = nil
        @logger.debug {"Checking If '#{title}' Is A New Show"}
        # we have to check each of the season/ep regex strings provided in the config file
        @main.rxSeasonEp.each do |rx|
            m = rxmatch(rx, title)
            # if m is nil then there was no match
            if m.nil?
                @logger.debug {"#{id} didn't match #{title} (#{rx})"}
            # if we did match, then we must extract the season/ep data
            # m[1] = season, m[2] = episode
            else
                @logger.debug {"#{id} Matches #{title} (#{rx})"}
                # remove non numeric characters from season and episode
                season = m[1].gsub(/[^0-9]/, '').to_i
                episode = m[2].gsub(/[^0-9]/, '').to_i
                # check if either we are in the same season and we haven't downloaded the provided episode, or if a new season has started
                @logger.debug {"'#{title}' is season #{season}, episode #{episode}"}
                if ((season == @season.to_i and not @episodes.include?(episode)) or season > @season.to_i)
                    @logger.info(false) {"Found New Show For #{@id}: Season #{season}, Episode #{episode} (#{@season}:#{@episodes.join(',')})"}
                    # all good, return the season and episode
                    ret = [true, season, episode]
                else
                    @logger.debug {"'#{title}' Is Old (S#{sprintf("%02d", @season)}, E:#{@episodes.join(',')})"}
                    ret = [false, season, episode]
                end
                break
            end
        end
        @logger.ftrace {'LEAVE'}
        ret
    end

    # check if title should be rejected based on the reject regex strings
    def reject?(title)
        @logger.ftrace {'ENTER'}
        ret = false
        @logger.debug {"Checking if '#{title}' should be rejected"}
        @main.rxReject.each do |rx|
            m = rxmatch(rx, title)
            unless m.nil?
                @logger.debug {"'#{title}' is rejected"}
                ret = true
                break
            end
        end

        @logger.ftrace {'LEAVE'}
        ret
    end

    def proper?(title, episode)
        @logger.ftrace {'ENTER'}
        ret = false
        if conf.has_key?('proper_override')
            @logger.debug {'Checking for PROPER release'}
            if title.upcase.include?('PROPER') and @episodes.include?(episode) == false
                ret = true
            end
        end
        @logger.ftrace{'LEAVE'}
        ret
    end

    # this is the main function that matches an input show title to *THIS* show object
    # i = feed item
    def match(i)
        @logger.ftrace {'ENTER'}
        ret = review = nil
        dlpath, review, ep_info = match_title(i.title)
        # if dlpath was set, then download that bitch! (with a timeout of course)
        Timeout::timeout(@main.torTimeout) { ret = download(i.link, dlpath, review) } unless dlpath.nil?
        # precedence to the download return state, then the review state
        ret = ret.nil? ? nil : review ? nil : ret
        # if nothing has gone wrong, update our status
        unless ret.nil?
            if (ep_info[1].to_i > @season)
                # new season detected, clear the current ep list
                @episodes.clear
            end
            @season = ep_info[1].to_i
            @episodes.push(ep_info[2]).sort!

            # finally, save the state to disk
            @main.save_state
        end
        @logger.ftrace {'LEAVE'}
        ret
    end

    def match_title(title)
        @logger.ftrace {'ENTER'}
        ret = nil
        @logger.debug {"Matching '#{title}' With '#{@regex}'"}
        m = rxmatch(@regex, title)
        # we didn't match
        if m.nil?
            @logger.debug {"#{@id} doesn't match"}
            ret = nil
        # we matched, so now we have to do the successful match logic
        else
            @logger.debug {"#{@id} matches '#{title}'"}
            # first check if the show is new
            ep_info = new_show?(title.gsub(m[m.length - 1], ''))
            dlpath = nil
            review = false
            dl = true
            # show's title doesn't have season/ep info, we download it anyways, but to the review dir
            if ep_info.nil?
                @logger.warn {"Couldn't Determine Season and Episode Info For '#{title}'"}
                dlpath = File.join(File.expand_path(conf['download_path_review']), "REVIEW-#{title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                review = true
            # if it is old, then we have nothing to do
            elsif ep_info[0] == false
                # download anyways if we want to override proper releases
                if proper?(title, ep_info[2] + 0.1)
                    @logger.notice(false) {"#{title} is a PROPER release, downloading even though it is old"}
                    dlpath = File.join(File.expand_path(conf['download_path']), "#{title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                    ep_info[2] += 0.1
                else
                    @logger.info {"#{title} is old, skipping"}
                    ret = nil
                end
            # make sure the show shouldn't be rejected, if it is a reject we still download it to the review dir
            elsif reject?(title)
                @logger.notice(false) {"'#{title}' Was Rejected"}
                dlpath = File.join(File.expand_path(conf['download_path_review']), "REVIEW-#{title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                review = true
            # otherwise, everything is good.  try and download the file
            else
                dlpath = File.join(File.expand_path(conf['download_path']), "#{title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                @logger.notice(false) {"Show '#{title}' has a new epidsode ready for download"}
            end
            ret = [dlpath, review, ep_info]
        end
        @logger.ftrace {'LEAVE'}
        ret
    end

    # download from uri to dlpath
    def download(uri, dlpath, review)
        @logger.ftrace {'ENTER'}
        ret = nil
        begin
            isMagnet = false
            uri = URI.escape(uri, '[]')
            @logger.info {"Escaped URI => #{uri}"}
            m = rxmatch('^magnet:.*btih:([a-zA-Z0-9]+)', uri)
            unless m.nil?
                @logger.info {'Magnet URI Detected'}
                if review
                    dlpath = File.join(File.expand_path(conf['download_path_review']), "REVIEW-meta-#{m[1]}.torrent")
                else
                    dlpath = File.join(File.expand_path(conf['download_path']), "meta-#{m[1]}.torrent")
                end
                isMagnet = true
            end

            # make sure a file of the same path doesn't already exist
            unless File.size?(dlpath).nil?
                @logger.warn {"'#{dlpath}' already exists, not downloading"}
                ret = nil
            else 
                if isMagnet
                    @logger.debug {"Creating Magnet File from #{uri} to #{dlpath}"}
                    File.open(dlpath, 'w') do |f|
                        f.write("d10:magnet-uri#{uri.length}:#{uri}e")
                        f.close
                    end
                    ret = dlpath
                else
                    @logger.debug {"Downloading #{uri} to #{dlpath}"}
                    # download the uri
                    File.open(dlpath, 'w') do |f|
                        f.write(open(uri).read)
                        f.close
                    end
                    ret = dlpath
                end
            end
        rescue => e
            @logger.error {"Download Error: #{e}\r\n#{e.backtrace}"}
            ret = nil
        end
        @logger.ftrace {'LEAVE'}
        ret
    end

    # load the state from the provided state item (from the state file)
    def load_state(si)
        @logger.ftrace {'ENTER'}
        return if si.length != 2
        @logger.debug {"Loading State For #{@id}: #{si.join(';')}"}
        @season = si[0].to_i
        @episodes = si[1].split(/,/).map { |e| e.to_i }.uniq
        @logger.ftrace {'LEAVE'}
        nil
    end

    # get the state
    def get_state
        @logger.ftrace {'ENTER'}
        @logger.debug {"State For #{@id}: #{@season};#{@episodes.join(',')}"}
        ret = "#{@season};#{@episodes.join(',')}"
        @logger.ftrace {'LEAVE'}
        ret
    end

    def to_s
<<EOF
------------------------
Show
------------------------
Show     : #{@id}
Regex    : #{@regex}
Season   : #{@season}
Episodes : #{@episodes.join(',')}
CMD      : #{@postdlcmd.nil? ? 'N/A' : @postdlcmd}
Feeds    : #{@feeds.nil? ? 'ALL' : @feeds.each_value.map { |f| f.id }.join(',')}
========================
EOF
    end
end

