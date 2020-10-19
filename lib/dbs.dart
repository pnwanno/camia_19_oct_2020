import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBTables{
  Future<Database> loginCon()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_camia.db");
    Database con= await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, verse){
        db.execute("create table user_login (id integer primary key, email text, password text, fullname text, dp text, phone text, status text, user_id text)");
      }
    );
    return con;
  }

  Future<Database> myProfileCon()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_camia_profile.db");
    Database con= await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, verse){
        db.execute("create table user_profile (id integer primary key, username text, dp text, website text, brief text, interests text, status text)");
        db.execute("create table wall_posts (id integer primary key, post_id text, post_image text)");
      }
    );
    return con;
  }

  Future<Database> wallPosts() async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_camia_wall_posts.db");
    Database con= await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, verse){
        db.execute("create table wall_posts (id integer primary key, post_id text, user_id text, post_images text, post_text text, views text, time_str text, likes text, comments text, post_link_to text, status text, book_marked text, media_server_loc text, dp text, username text, fullname text, section text, save_time text)");
        db.execute("create table followers (id integer primary key, user_id text, user_name text, dp text)");
      }
    );
    return con;
  }

  Future<Database> tvProfile()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_camtv_profile.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table profile (id integer primary key, channel_name text, dp text, website text, brief text, status text, channel_id text, interests text)");
          db.execute("create table tv_posts (id integer primary key, channel_id text, post_id text, user_id text, title text, post_text text, duration text, ar text, post_path text, poster_path text, channel_dp text, channel_name text, views text, post_time text, recommended_as text, likes text)");
        }
    );
    return con;
  }

  Future<Database> chFinder()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_chapter_finder.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table chapter_details (id integer primary key, chapter_id text, zone text, chapter text, location text, address text, contact_person text, phone text, email text, social text)");
          db.execute("create table search_history (id integer primary key, search_q text, time_str text)");
        }
    );
    return con;
  }

  Future<Database> citiMag()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_citi_mag.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table magazines (id integer primary key, title text, about text, period text, bookmarked text, mag_id text, pages text, status text, page_path text, ar text, pages_dl text, time_str text)");
        }
    );
    return con;
  }

  Future<Database> lwDict()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_lwdict.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table dict_words (id integer primary key, title text, definition text, source_txt text, bookmarked text, word_id text)");
          db.execute("create table day_word (id integer primary key, title text, definition text, source_txt text, word_id text, day text)");
          db.execute("create table weekly_quotes (id integer primary key, quote_by text, quote text, week text)");
          db.execute("create table affirmations (id integer primary key, text text, day text)");
          db.execute("create table search_history (id integer primary key, title text, word_id text, time_str text)");
        }
    );
    return con;
  }

  Future<Database> kjutCache()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_file_cache.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table kcache (id integer primary key, url text, fname text, cache_till text, status text)");
        }
    );
    return con;
  }

  Future<Database> cmNews()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_cm_news.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table cm_news (id integer primary key, category text, title text, media_path text, dp text, ar text, news_date text, news_id text, news_date_str text)");
        }
    );
    return con;
  }

  Future<Database> dm()async{
    String dbLoc=await getDatabasesPath();
    String dbPath= join(dbLoc, "kjut_dm.db");
    Database con= await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, verse){
          db.execute("create table profile (id integer primary key, username text, fullname text, dp text, file_name text, about text, phone text)");
          db.execute("create table chats (id integer primary key, chat_id text, user_id text, user_phone text, user_name text, msg text, media text, reply_to text, msg_time text, read_state text)");
          db.execute("create table contacts (id integer primary key, user_id text, username text, display_name text, account_fullname text, user_phone text, dp text, file_name text, about text)");
        }
    );
    return con;
  }
}