# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/app'

RSpec.describe 'Health endpoint' do
  def app = Reader::App

  it 'returns 200 with status ok' do
    get '/health'
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['status']).to eq('ok')
  end
end
