require 'sinatra/base'
require 'json'
require_relative 'models.rb'
require 'c50e-config.rb'  # TODO: some should be site constants
require 'b50d/peeps'
require 'b50d/sivers-comments'
require 'c50e/form_filter'

PP = B50D::Peeps.new(C50E::config[:api_key], C50E::config[:api_pass])
SC = B50D::SiversComments.new(C50E::config[:api_key], C50E::config[:api_pass])

## DYNAMIC (non-static) parts of sivers.org:
# 1. posting a comment
# 2. mailing list: un/subscribe
# 3. ebook: post name&email / lopass URL to download
# 4. AnythingYouWant: post proof, login, MP3-list, download
# 5. password forgot/reset

## URL paths for nginx to pass to proxy:
#  ^/(comments|list/|list\Z|u/|ayw/|download/)

class SiversOrg < Sinatra::Base

	# nginx might rewrite looking for /uri/home or just /uri/. both are wrong.
	get %r{/home\Z|/\Z} do
		redirect '/'
	end

	# COMMENTS: post to add comment 
	post '/comments' do
		comment = FormFilter::comment(request.env, SC)
		if comment && comment[:id]
			redirect '%s#comment-%d' % [request.referrer, comment[:id]]
		else
			redirect request.referrer
		end
	end

	# LIST: pre-authorized URL to show form for changing settings / unsubscribing
	get %r{\A/list/([0-9]+)/([a-zA-Z0-9]{4})\Z} do |person_id, lopass|
		@bodyid = 'list'
		@pagetitle = 'email list'
		p = PP.get_person_lopass(person_id, lopass)
		@show_name = p ? p[:name] : ''
		@show_email = p ? p[:email] : ''
		erb :list
	end

	# LIST: just show the static form
	get '/list' do
		@bodyid = 'list'
		@pagetitle = 'email list'
		@show_name = @show_email = ''
		erb :list
	end

	# LIST: handle posting of list signup or changing settings
	post '/list' do
		if FormFilter::mailinglist(request.env, PP)
			redirect('/thanks?for=list')
		else
			redirect '/list'
		end
	end

	# DOWNLOAD: id+lopass auth to get a file
	get %r{\A/download/([0-9]+)/([a-zA-Z0-9]{4})/([a-zA-Z0-9\._-]+)\Z} do |person_id, lopass, filename|
		whitelist = %w(DerekSivers.pdf)
		redirect '/sorry?for=notfound' unless whitelist.include?(filename)
		redirect '/sorry?for=login' unless PP.get_person_lopass(person_id, lopass)
		send_file "/srv/http/downloads/#{filename}"
	end

	# sivers.org/pdf posts here to get ebook
	# TODO: merge this AYW stuff into others
	post '/download/ebook' do
		redirect '/pdf' unless AYW.valid?(request.env)
		nu = {person_id: AYW.person_id(request.env), statkey: 'ebook', statvalue: 'requested'}
		Userstat.create(nu)
		p = Person[nu[:person_id]]
		f = Formletter[Sivers.config['formletter_download_pdf']]
		h = {profile: 'derek@sivers', subject: p.firstname + ' - How to Call Attention To Your Music'}
		f.send_to(p, h)
		redirect '/thanks?for=pdf'
	end

	# PASSWORD: semi-authorized. show form to make/change real password
	get %r{\A/u/([0-9]+)/([a-zA-Z0-9]{8})\Z} do |person_id, newpass|
		p = Person.where(id: person_id, newpass: newpass).first
		redirect '/sorry?for=badurlid' unless p
		@person_id = person_id
		@newpass = newpass
		@bodyid = 'newpass'
		@pagetitle = 'new password'
		erb :newpass
	end

	# PASSWORD: posted here to make/change it. then log in with cookie
	post '/u/password' do
		p = Person.where(id: params[:person_id], newpass: params[:newpass]).first
		redirect '/sorry?for=badurlid' unless p
		redirect '/sorry?for=shortpass' unless params[:password].to_s.size >= 4
		p.set_password(params[:password])
		p.set_newpass
		if ['sivers.org', 'sivers.dev', 'example.org'].include? request.env['SERVER_NAME']
			ok = Login.set_auth(p.id, request.env['SERVER_NAME'])
			response.set_cookie('ok', value: ok, path: '/', httponly: true)
		end
		redirect '/ayw/list'
	end

	# PASSWORD: forgot? form to enter email
	get '/u/forgot' do
		@bodyid = 'forgot'
		@pagetitle = 'forgot password'
		erb :forgot
	end

	# PASSWORD: email posted here. send password reset link
	post '/u/forgot' do
		p = Person[email: params[:email]]
		redirect '/sorry?for=noemail' unless p
		p.set_newpass
		f = Formletter[Sivers.config['formletter_password_reset']]
		h = {profile: 'derek@sivers', subject: p.firstname + ' - your password reset link'}
		f.send_to(p, h)
		redirect '/thanks?for=reset'
	end

	# AYW post code word + name & email. if right, emails login link
	# (if you are reading this, yes the codeword is here. it's intentionally not very secret.)
	post '/ayw/proof' do
		redirect '/sorry?for=aywcode' unless /utopia/i === params[:code]
		p = AYW.update(request.env)
		f = Formletter[Sivers.config['formletter_ayw_bought']]
		h = {profile: 'derek@sivers', subject: p.firstname + ' - your MP3 download link'}
		f.send_to(p, h)
		redirect '/thanks?for=ayw'
	end

	# log in form to get to AYW MP3 download area
	get '/ayw/login' do
		p = Login.get_person_from_cookie(request.cookies['ok'])
		redirect '/ayw/list' if p
		@bodyid = 'ayw'
		@pagetitle = 'log in for MP3 downloads'
		erb :ayw_login
	end

	# post login form to get into list of MP3s
	post '/ayw/login' do
		p = Person.find_by_email_pass(params[:email], params[:password])
		if p && (['sivers.org', 'sivers.dev', 'example.org'].include? request.env['SERVER_NAME'])
			ok = Login.set_auth(p.id, request.env['SERVER_NAME'])
			response.set_cookie('ok', value: ok, path: '/', httponly: true)
			redirect '/ayw/list'
		else
			redirect '/sorry?for=badlogin'
		end
	end

	# AYW list of MP3 downloads - only for the authorized
	get '/ayw/list' do
		p = Login.get_person_from_cookie(request.cookies['ok'])
		redirect '/ayw/login' unless p
		@bodyid = 'ayw'
		@pagetitle = 'MP3 downloads for Anything You Want book'
		erb :ayw_list
	end

	# AYW MP3 downloads 
	get %r{\A/ayw/download/([A-Za-z-]+.zip)\Z} do |zipfile|
		p = Login.get_person_from_cookie(request.cookies['ok'])
		redirect '/sorry?for=login' unless p
		redirect '/ayw/list' unless %w(AnythingYouWant.zip CLASSICAL-AnythingYouWant.zip COUNTRY-AnythingYouWant.zip FOLK-AnythingYouWant.zip JAZZ-AnythingYouWant.zip OTHER-AnythingYouWant.zip POP-AnythingYouWant.zip ROCK-AnythingYouWant.zip SAMPLER-AnythingYouWant.zip SINGSONG-AnythingYouWant.zip URBAN-AnythingYouWant.zip WORLD-AnythingYouWant.zip).include? zipfile
		send_file "/srv/http/downloads/#{zipfile}"
	end

end
