require 'sinatra'
require 'sinatra/json'
require 'securerandom'
require 'docker'
require 'logger'

# initialize logger
logger = Logger.new(STDOUT)

# initialize docker
Docker.url = ENV['DOCKER_URL'] || Docker.url
DOCKER_IMAGE_NAME = ENV['DOCKER_IMAGE_NAME'] || 'ruby:2.5-alpine'
Docker::Image.create(fromImage: DOCKER_IMAGE_NAME)
logger.info "DOCKER_URL: #{Docker.url}"
logger.info "DOCKER_IMAGE: #{DOCKER_IMAGE_NAME}"

# initialize sinatra
set :bind, '0.0.0.0'

get '/' do
  erb :index
end

post '/' do
  output = ''

  Dir.mktmpdir do |tmpdir|
    Tempfile.create([SecureRandom.hex, '.rb'], tmpdir) do |f|
      f.write(params[:code])
      f.flush
      begin
        container = Docker::Container.create(
          Cmd: ["ruby", "#{f.path}"], Image: DOCKER_IMAGE_NAME, Binds: ["#{tmpdir}:#{tmpdir}:ro"],
          AttachStdout: true, AttachStderr: true, Tty: true, Privileged: true
        )
        container.start.attach
        container.stop
        output = container.logs(stdout: true, stderr: true)
        container.remove
      rescue => e
        logger.warn e.message
        e.backtrace.each(&logger.method(:warn))
        if defined?(:container)
          container&.stop
          container&.remove
        end
      end
    end
  end

  json content:  output
end
