#!/usr/bin/ruby

require 'mime'
require 'rb_tuntap'
require 'packetfu'
require 'net/smtp'
require 'net/imap'
require "base64"
require "date"
require 'optparse'

dest_address = nil
src_address = nil
smtp_host = nil
smtp_username = nil
smtp_passwd = nil
imap_host = nil
imap_username = nil
imap_passwd = nil
ip_address = nil

parser = OptionParser.new do |opts|
  opts.banner = "Usage: dovetail.rb [options]"

  opts.on(:REQUIRED, "-d", "--destination", "Destination e-mail address") do |v|
    dest_address = v
  end
  opts.on(:REQUIRED, "-s", "--source", "Source e-mail address") do |v|
    src_address = v
  end
  opts.on(:REQUIRED, "-i", "--imap-server", "IMAP server") do |v|
    imap_host = v
  end
  opts.on(:REQUIRED, "-u", "--imap-user", "IMAP user") do |v|
    imap_username = v
  end
	opts.on(:REQUIRED, "-p", "--imap-password", "IMAP password") do |v|
    imap_passwd = v
  end
	opts.on(:REQUIRED, "-S", "--smtp-server", "SMTP server ") do |v|
    smtp_host = v
  end
 	opts.on(:REQUIRED, "-U", "--smtp-user", "SMTP user") do |v|
    smtp_username = v
  end
	opts.on(:REQUIRED, "-P", "--smtp-password", "SMTP password") do |v|
    smtp_passwd = v
  end
	opts.on(:REQUIRED, "-I", "--ip-address", "Local IP address") do |v|
    ip_address = v
  end
end

parser.parse!

if dest_address == nil or
	 src_address == nil or
	 imap_host == nil or
	 imap_username == nil or
	 imap_passwd == nil or
	 smtp_host == nil or
	 smtp_username == nil or
	 smtp_passwd == nil or
	 ip_address == nil
then
	puts parser.to_s
	exit
end

tun = RbTunTap::TunDevice.new("tun0")
tun.open(false)

tun.addr    = ip_address
tun.netmask = "255.255.255.0"

tun.up

tio = tun.to_io
seqnr = 0

sth = Thread.new do
	puts "Send thread started"

	loop do
		raw = tio.sysread(tun.mtu)

		begin
			ip = PacketFu::IPHeader.new.read(raw)
			puts "IP packet to " + ip.ip_daddr
			b64 = Base64.encode64(raw)
			p b64

			smtp = Net::SMTP.new(smtp_host, 587)
			smtp.enable_starttls

			smtp.start(Socket.gethostname, smtp_username, smtp_passwd, :plain) do |s|
				now = DateTime.now.strftime("%a, %d %b %Y %T %z")
				s.send_message(
					"From: #{src_address}\nTo: #{dest_address}\nSubject: Dovetail Seq# #{seqnr.to_s}\nDate: #{now}\n\n#{b64}",
					src_address,
					dest_address
				)
			end

			seqnr += 1
		rescue Exception => e
			p e
		end
	end
	puts "Send thread terminated"
end

rth = Thread.new do
	puts "Recv thread started"

	begin
		imap = Net::IMAP.new(imap_host,{:port => 143})
	p	imap.starttls
		imap.authenticate('PLAIN', imap_username, imap_passwd)
		imap.select('INBOX')

		loop do
			imap.search(['SUBJECT','Dovetail','UNSEEN']).each do |message_id|
				body = imap.fetch(message_id,'BODY[TEXT]')[0].attr['BODY[TEXT]']
				p body
				raw = Base64.decode64(body)
				ip = PacketFu::IPHeader.new.read(raw)
				puts "IP packet from " + ip.ip_saddr

				tio.syswrite(raw)
				imap.store(message_id,"+FLAGS",[:Seen])
			end

			imap.idle do |resp|
				p resp
				if resp.kind_of?(Net::IMAP::UntaggedResponse) and resp.name == "FETCH"
					imap.idle_done
				end
			end
		end
	rescue Exception => e
			puts "Recv: #{e}"
	end

	puts "Recv thread terminated"
end

rth.join
sth.join

tun.down
tun.close
