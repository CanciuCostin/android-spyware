require 'rails_helper'

RSpec.describe FileTransfersController, type: :controller do
  let(:apk_payload) { create(:apk_payload) }
  let(:apk_installation) { create(:apk_installation, apk_payload: apk_payload) }
  let(:device) { create(:smartphone, apk_installation: apk_installation) }
  let(:valid_token) { 'test-device-token-12345' }
  let(:upload_id) { SecureRandom.uuid }
  let(:filename) { 'test_file.jpg' }
  
  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token
    request.headers['X-Device-Token'] = valid_token
    
    # Cleanup any existing uploads
    FileUtils.rm_rf(Rails.root.join('tmp', 'uploads'))
    FileUtils.rm_rf(Rails.root.join('files', 'uploads'))
  end
  
  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
    FileUtils.rm_rf(Rails.root.join('tmp', 'uploads'))
    FileUtils.rm_rf(Rails.root.join('files', 'uploads'))
  end
  
  describe 'POST #upload_chunk' do
    context 'with valid authentication' do
      context 'single chunk upload' do
        it 'successfully uploads a single chunk' do
          file_content = 'test file content'
          file = Rack::Test::UploadedFile.new(
            StringIO.new(file_content),
            'image/jpeg',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: 0,
            total_chunks: 1,
            file: file,
            filename: filename
          }
          
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['upload_id']).to eq(upload_id)
          expect(json['chunk_index']).to eq(0)
          expect(json['progress']).to eq(100.0)
        end
      end
      
      context 'multiple chunk upload' do
        it 'successfully uploads multiple chunks in order' do
          total_chunks = 3
          chunks = ['chunk1data', 'chunk2data', 'chunk3data']
          
          chunks.each_with_index do |chunk_data, index|
            file = Rack::Test::UploadedFile.new(
              StringIO.new(chunk_data),
              'application/octet-stream',
              true
            )
            
            post :upload_chunk, params: {
              device_id: device.id,
              upload_id: upload_id,
              chunk_index: index,
              total_chunks: total_chunks,
              file: file,
              filename: filename
            }
            
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['success']).to be true
            expect(json['chunk_index']).to eq(index)
            
            expected_progress = ((index + 1).to_f / total_chunks * 100).round(2)
            expect(json['progress']).to eq(expected_progress)
          end
        end
        
        it 'handles out-of-order chunk uploads' do
          total_chunks = 3
          chunks = [
            { index: 2, data: 'chunk3' },
            { index: 0, data: 'chunk1' },
            { index: 1, data: 'chunk2' }
          ]
          
          chunks.each do |chunk_info|
            file = Rack::Test::UploadedFile.new(
              StringIO.new(chunk_info[:data]),
              'application/octet-stream',
              true
            )
            
            post :upload_chunk, params: {
              device_id: device.id,
              upload_id: upload_id,
              chunk_index: chunk_info[:index],
              total_chunks: total_chunks,
              file: file,
              filename: filename
            }
            
            expect(response).to have_http_status(:ok)
          end
          
          # Verify all chunks are tracked in metadata
          metadata_path = Rails.root.join('tmp', 'uploads', "#{upload_id}.meta")
          expect(File.exist?(metadata_path)).to be true
          
          metadata = JSON.parse(File.read(metadata_path))
          expect(metadata['chunks_received'].sort).to eq([0, 1, 2])
        end
      end
      
      context 'chunk reassembly' do
        it 'assembles chunks into a single file' do
          chunks = ['AAAA', 'BBBB', 'CCCC']
          
          chunks.each_with_index do |chunk_data, index|
            file = Rack::Test::UploadedFile.new(
              StringIO.new(chunk_data),
              'application/octet-stream',
              true
            )
            
            post :upload_chunk, params: {
              device_id: device.id,
              upload_id: upload_id,
              chunk_index: index,
              total_chunks: chunks.size,
              file: file,
              filename: filename
            }
          end
          
          upload_path = Rails.root.join('tmp', 'uploads', upload_id)
          expect(File.exist?(upload_path)).to be true
          expect(File.read(upload_path)).to eq('AAAABBBBCCCC')
        end
      end
      
      context 'duplicate chunk handling' do
        it 'handles duplicate chunk uploads gracefully' do
          file_data = 'chunk1'
          
          # Upload same chunk twice
          2.times do
            file = Rack::Test::UploadedFile.new(
              StringIO.new(file_data),
              'application/octet-stream',
              true
            )
            
            post :upload_chunk, params: {
              device_id: device.id,
              upload_id: upload_id,
              chunk_index: 0,
              total_chunks: 2,
              file: file,
              filename: filename
            }
            
            expect(response).to have_http_status(:ok)
          end
          
          # Verify chunk is only counted once in metadata
          metadata_path = Rails.root.join('tmp', 'uploads', "#{upload_id}.meta")
          metadata = JSON.parse(File.read(metadata_path))
          expect(metadata['chunks_received'].count(0)).to eq(1)
        end
      end
      
      context 'invalid chunk rejection' do
        it 'rejects chunks with invalid upload_id format' do
          file = Rack::Test::UploadedFile.new(
            StringIO.new('data'),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: 'invalid-id',
            chunk_index: 0,
            total_chunks: 1,
            file: file,
            filename: filename
          }
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
        
        it 'rejects chunks with negative chunk_index' do
          file = Rack::Test::UploadedFile.new(
            StringIO.new('data'),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: -1,
            total_chunks: 1,
            file: file,
            filename: filename
          }
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
        
        it 'rejects chunks with chunk_index >= total_chunks' do
          file = Rack::Test::UploadedFile.new(
            StringIO.new('data'),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: 5,
            total_chunks: 3,
            file: file,
            filename: filename
          }
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
        
        it 'rejects chunks larger than MAX_CHUNK_SIZE' do
          large_data = 'A' * (11 * 1024 * 1024) # 11MB (over limit)
          file = Rack::Test::UploadedFile.new(
            StringIO.new(large_data),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: 0,
            total_chunks: 1,
            file: file,
            filename: filename
          }
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
        
        it 'rejects uploads with too many chunks' do
          file = Rack::Test::UploadedFile.new(
            StringIO.new('data'),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: 0,
            total_chunks: 20000, # Over MAX_TOTAL_CHUNKS
            file: file,
            filename: filename
          }
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
      
      context 'concurrent uploads' do
        it 'handles multiple concurrent uploads to different upload_ids' do
          upload_ids = [SecureRandom.uuid, SecureRandom.uuid, SecureRandom.uuid]
          results = []
          
          upload_ids.each do |uid|
            file = Rack::Test::UploadedFile.new(
              StringIO.new("data-#{uid}"),
              'application/octet-stream',
              true
            )
            
            post :upload_chunk, params: {
              device_id: device.id,
              upload_id: uid,
              chunk_index: 0,
              total_chunks: 1,
              file: file,
              filename: "file-#{uid}.txt"
            }
            
            results << response.status
          end
          
          # Verify all uploads succeeded
          expect(results).to all(eq(200))
          
          # Verify all uploads created separate files
          upload_ids.each do |uid|
            upload_path = Rails.root.join('tmp', 'uploads', uid)
            expect(File.exist?(upload_path)).to be true
          end
        end
      end
    end
    
    context 'without authentication' do
      before do
        request.headers['X-Device-Token'] = nil
      end
      
      it 'rejects upload without token' do
        file = Rack::Test::UploadedFile.new(
          StringIO.new('data'),
          'application/octet-stream',
          true
        )
        
        post :upload_chunk, params: {
          device_id: device.id,
          upload_id: upload_id,
          chunk_index: 0,
          total_chunks: 1,
          file: file,
          filename: filename
        }
        
        expect(response).to have_http_status(:unauthorized)
      end
      
      it 'rejects upload with invalid token' do
        request.headers['X-Device-Token'] = 'invalid-token'
        
        file = Rack::Test::UploadedFile.new(
          StringIO.new('data'),
          'application/octet-stream',
          true
        )
        
        post :upload_chunk, params: {
          device_id: device.id,
          upload_id: upload_id,
          chunk_index: 0,
          total_chunks: 1,
          file: file,
          filename: filename
        }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
  
  describe 'POST #finalize_upload' do
    context 'with all chunks uploaded' do
      before do
        # Upload all chunks first
        3.times do |i|
          file = Rack::Test::UploadedFile.new(
            StringIO.new("chunk#{i}"),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: i,
            total_chunks: 3,
            file: file,
            filename: filename
          }
        end
      end
      
      it 'successfully finalizes the upload' do
        post :finalize_upload, params: {
          device_id: device.id,
          upload_id: upload_id,
          filename: filename
        }
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['filename']).to eq(filename)
        expect(json['upload_id']).to eq(upload_id)
        
        # Verify file moved to final destination
        final_path = Rails.root.join('files', 'uploads', filename)
        expect(File.exist?(final_path)).to be true
        expect(File.read(final_path)).to eq('chunk0chunk1chunk2')
        
        # Verify temp files cleaned up
        temp_path = Rails.root.join('tmp', 'uploads', upload_id)
        expect(File.exist?(temp_path)).to be false
      end
      
      it 'includes correct file size in response' do
        post :finalize_upload, params: {
          device_id: device.id,
          upload_id: upload_id,
          filename: filename
        }
        
        json = JSON.parse(response.body)
        expect(json['size']).to eq('chunk0chunk1chunk2'.bytesize)
      end
    end
    
    context 'with missing chunks' do
      before do
        # Upload only 2 of 3 chunks
        2.times do |i|
          file = Rack::Test::UploadedFile.new(
            StringIO.new("chunk#{i}"),
            'application/octet-stream',
            true
          )
          
          post :upload_chunk, params: {
            device_id: device.id,
            upload_id: upload_id,
            chunk_index: i,
            total_chunks: 3,
            file: file,
            filename: filename
          }
        end
      end
      
      it 'fails finalization with missing chunks error' do
        post :finalize_upload, params: {
          device_id: device.id,
          upload_id: upload_id,
          filename: filename
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Missing chunks')
      end
    end
    
    context 'with non-existent upload_id' do
      it 'fails finalization' do
        post :finalize_upload, params: {
          device_id: device.id,
          upload_id: SecureRandom.uuid,
          filename: filename
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
