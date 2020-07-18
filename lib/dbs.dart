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
        db.execute("create table user_profile (id integer primary key, username text, dp text, website text, brief text, post_count text, follower text, following text, website_title text, website_description text, status text)");
        db.execute("create table wall_posts (id integer primary key, post_id text, post_image text)");
        db.execute("create table wall_post_tag (id integer primary key, post_id text, post_image text)");
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
}