class AddSearchVectors < ActiveRecord::Migration[8.0]
  def up
    # Add search_vector column to all searchable tables
    
    # Artists
    unless column_exists?(:artists, :search_vector)
      add_column :artists, :search_vector, :tsvector
      add_index :artists, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE artists SET search_vector = 
          setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(bio, '')), 'B');
      SQL
    end
    
    # Albums
    unless column_exists?(:albums, :search_vector)
      add_column :albums, :search_vector, :tsvector
      add_index :albums, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE albums a SET search_vector = 
          setweight(to_tsvector('english', coalesce(a.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(a.description, '')), 'B') ||
          setweight(to_tsvector('english', coalesce((SELECT name FROM artists WHERE id = a.artist_id), '')), 'B');
      SQL
    end
    
    # Tracks
    unless column_exists?(:tracks, :search_vector)
      add_column :tracks, :search_vector, :tsvector
      add_index :tracks, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE tracks t SET search_vector = 
          setweight(to_tsvector('english', coalesce(t.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce((SELECT ar.name FROM albums al JOIN artists ar ON al.artist_id = ar.id WHERE al.id = t.album_id), '')), 'B');
      SQL
    end
    
    # Videos
    unless column_exists?(:videos, :search_vector)
      add_column :videos, :search_vector, :tsvector
      add_index :videos, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE videos v SET search_vector = 
          setweight(to_tsvector('english', coalesce(v.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(v.description, '')), 'B') ||
          setweight(to_tsvector('english', coalesce((SELECT name FROM artists WHERE id = v.artist_id), '')), 'B');
      SQL
    end
    
    # Minis
    unless column_exists?(:minis, :search_vector)
      add_column :minis, :search_vector, :tsvector
      add_index :minis, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE minis m SET search_vector = 
          setweight(to_tsvector('english', coalesce(m.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(m.description, '')), 'B') ||
          setweight(to_tsvector('english', coalesce((SELECT name FROM artists WHERE id = m.artist_id), '')), 'B');
      SQL
    end
    
    # Events
    unless column_exists?(:events, :search_vector)
      add_column :events, :search_vector, :tsvector
      add_index :events, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE events e SET search_vector = 
          setweight(to_tsvector('english', coalesce(e.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(e.description, '')), 'B') ||
          setweight(to_tsvector('english', coalesce(e.venue, '')), 'C') ||
          setweight(to_tsvector('english', coalesce(e.location, '')), 'C') ||
          setweight(to_tsvector('english', coalesce((SELECT name FROM artists WHERE id = e.artist_id), '')), 'B');
      SQL
    end
    
    # Merch Items
    unless column_exists?(:merch_items, :search_vector)
      add_column :merch_items, :search_vector, :tsvector
      add_index :merch_items, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE merch_items m SET search_vector = 
          setweight(to_tsvector('english', coalesce(m.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(m.description, '')), 'B') ||
          setweight(to_tsvector('english', coalesce(m.brand, '')), 'C') ||
          setweight(to_tsvector('english', coalesce((SELECT name FROM artists WHERE id = m.artist_id), '')), 'B');
      SQL
    end
    
    # Livestreams
    unless column_exists?(:livestreams, :search_vector)
      add_column :livestreams, :search_vector, :tsvector
      add_index :livestreams, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE livestreams l SET search_vector = 
          setweight(to_tsvector('english', coalesce(l.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(l.description, '')), 'B') ||
          setweight(to_tsvector('english', coalesce((SELECT name FROM artists WHERE id = l.artist_id), '')), 'B');
      SQL
    end
    
    # Playlists
    unless column_exists?(:playlists, :search_vector)
      add_column :playlists, :search_vector, :tsvector
      add_index :playlists, :search_vector, using: :gin
      
      execute <<-SQL
        UPDATE playlists p SET search_vector = 
          setweight(to_tsvector('english', coalesce(p.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(p.description, '')), 'B');
      SQL
    end
  end
  
  def down
    remove_column :artists, :search_vector if column_exists?(:artists, :search_vector)
    remove_column :albums, :search_vector if column_exists?(:albums, :search_vector)
    remove_column :tracks, :search_vector if column_exists?(:tracks, :search_vector)
    remove_column :videos, :search_vector if column_exists?(:videos, :search_vector)
    remove_column :minis, :search_vector if column_exists?(:minis, :search_vector)
    remove_column :events, :search_vector if column_exists?(:events, :search_vector)
    remove_column :merch_items, :search_vector if column_exists?(:merch_items, :search_vector)
    remove_column :livestreams, :search_vector if column_exists?(:livestreams, :search_vector)
    remove_column :playlists, :search_vector if column_exists?(:playlists, :search_vector)
  end
end

