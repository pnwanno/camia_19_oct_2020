import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../globals.dart' as globals;
import '../dbs.dart';
import './edit_profile.dart';

class MyWallProfile extends StatefulWidget{
  _MyWallProfile createState(){
    return _MyWallProfile();
  }
}

class _MyWallProfile extends State<MyWallProfile> with SingleTickerProviderStateMixin{
  TabController postTagCtr;

  String username= globals.fullname;
  Widget dp=Container(); String dpfname="";
  String postCount="0";
  String followerCount= "0";
  String followingCount="0";
  String profileWebsite="", profileBrief="";
  DBTables dbTables= DBTables();
  Directory _appdir;
  ScrollController mainListCtr;
  ScrollPhysics postTagPhysics;
  bool firstLoad=true;
  bool fetchFromServer=true;
  @override
  void initState() {
    super.initState();
    mainListCtr=ScrollController();
    //postTagPhysics=ScrollPhysics();
    dp=CircleAvatar(
      radius: 45,
      child: Text(
        username.substring(0,1),
        style: TextStyle(
          fontSize: 32
        ),
      ),
    );

    postTagCtr= TabController(
      length: 2, vsync: this
    );
    fetchFromServer=true;
    getLocalUData();
    getLocalPosts();
  }//initstate

  launchLink(String ulink)async{
    if(await launcher.canLaunch(ulink)){
      launcher.launch(ulink);
    }
  }

  String profileWebTitle="";
  String profileWebDescription="";
  getProfileWebsite(String url)async{
    try{
      http.Response resp= await http.get("https://$url");
      if(resp.statusCode == 200){
        RegExp headExp= RegExp(r"<head[^>]*>([\s\S]*?)<\/head>", caseSensitive: false);
        RegExpMatch match=headExp.firstMatch(resp.body);
        if(match != null){
          String headTag=match.group(0);
          RegExp titlTagExp=RegExp(r"<title[^>]*>([\s\S]*?)<\/title>", caseSensitive: false);
          RegExpMatch titleMatch= titlTagExp.firstMatch(headTag);
          if(titleMatch!=null){
            profileWebTitle=titleMatch.group(1);
          }

          RegExp descMetaExp=RegExp("<meta .*?name=['\"]?description['\"]? .*?content=['\"](.+?)['\"]");
          RegExpMatch descMatch= descMetaExp.firstMatch(headTag);
          if(descMatch!=null){
            profileWebDescription=descMatch.group(1);
          }
          
          setState(() {});
          Database con= await dbTables.myProfileCon();
          con.execute("update user_profile set website_title=?, website_description=? where status='active'", [profileWebTitle, profileWebDescription]);
        }
      }
    }
    catch(ex){

    }
  }//getprofile website

  ///Gets data from the phone's database
  ///Such data as -the post count, follower count, ... and such like that
  ///basically an offline copy of the server's data on the user's profile
  Future<void> getLocalUData()async{
    _appdir=await getApplicationDocumentsDirectory();
    Database con=await dbTables.myProfileCon();
    var result= await con.rawQuery("select * from user_profile where status='active'");
    if(result.length == 1){
      var rw= result[0];
      username=rw["username"];
      profileBrief=rw["brief"];

      RegExp htExp=RegExp(r"^https?\:\/\/", caseSensitive: false);
      profileWebsite= rw["website"];
      profileWebsite=profileWebsite.replaceFirst(htExp, "");
      profileWebTitle= rw["website_title"];
      profileWebDescription=rw["website_description"];
      getProfileWebsite(profileWebsite);

      postCount= rw["post_count"];
      followerCount=rw["follower"];
      followingCount=rw["following"];
      dpfname=rw["dp"];
      
      File tmpDp= File(_appdir.path + "/wall_dir/$dpfname");
      if(await tmpDp.exists()){
        dp=CircleAvatar(
          backgroundImage: FileImage(tmpDp),
          radius: 45,
        );
      }
      setState(() {
        
      });
      firstLoad=false;
      if(fetchFromServer){
         updateDB();
      }
    }
  }//getlocaldata

  ///This method tries to update the local database with a copy of the 
  ///Server's data, with data such as the post count, followers count, ...
  updateDB()async{
    String url=globals.globBaseUrl + "?process_as=get_my_wall_profile";
    try{
      http.Response resp= await http.post(
        url,
        body: {
          "user_id": globals.userId,
          "current_dp": dpfname
        }
      );
      if(resp.statusCode == 200){
        Map respObj= jsonDecode(resp.body);
        if(respObj.containsKey("basic")){
          var basicData= respObj["basic"];
          String serverDpStr= basicData["dp_str"];
          String serverUname=basicData["username"];
          String serverUwebsite=basicData["website"];
          String serverUbrief=basicData["brief"];
          String serverpcount=basicData["post_count"];
          String serverUfollower=basicData["followers"];
          String serverUFollowing=basicData["following"];

          Database con= await dbTables.myProfileCon();
          con.execute("update user_profile set username=?, dp=?, website=?, brief=?, post_count=?, follower=?, following=? where status='active'", [serverUname, serverDpStr, serverUwebsite, serverUbrief, serverpcount, serverUfollower, serverUFollowing]);
          if(dpfname != serverDpStr){
            File curWallDpFile= File(_appdir.path + "/wall_dir/$dpfname");
            if(await curWallDpFile.exists()){
              curWallDpFile.delete();
            }

            File newwallDp=File(_appdir.path + "/wall_dir/$serverDpStr");
            await newwallDp.writeAsBytes(base64Decode(basicData["dp"]));

            //refresh the data on the page
            fetchFromServer=false;
            getLocalUData();
          }
        }
      }
    }
    catch(ex){
      
    }
  }//update db

  
  List<Widget> localPostsData=List<Widget>();
  String postStartIndex="0";
  Widget localPosts= Container(child: Center(child: CircularProgressIndicator(),),);
  Widget localWallTags= Container(child: Center(child: CircularProgressIndicator(),),);

  ///This method tries to download a single image of the user's post
  ///to serve as placeholder for the user, offline
  Future<void> getLocalPosts({bool callFromServerUpdate=false})async{
    Database con= await dbTables.myProfileCon();
    List<Map> result= await con.rawQuery("select * from wall_posts order by id desc limit $postStartIndex,20");
    int kount= result.length;
    for(int k=0; k<kount; k++){
      File tmpFile= File(_appdir.path + "/wall_dir/my_post_images/" + result[k]["post_image"]);
      localPostsData.add(
        GestureDetector(
          onTap: (){

          },
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(tmpFile),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter
              )
            ),
          ),
        )
      );
    }
    localPosts= GridView.builder(
      itemCount: localPostsData.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3
      ),
      itemBuilder: (BuildContext ctx, int itemIndex){
        return localPostsData[itemIndex];
      }
    );
    setState(() {
      
    });

    //get content from the server to update local data
    if(callFromServerUpdate==false){
      updateLocalPosts();
    }
  }//getLocalPosts

  ///Updates the local post repository with recent content (or changes) from the 
  ///server data
  Future<void> updateLocalPosts()async{
    String url= globals.globBaseUrl + "?process_as=get_user_wall_post_stamp";
    try{
      http.Response resp= await http.post(
        url,
        body: {
          "request_id": globals.userId,
          "user_id": globals.userId
        }
      );
      if(resp.statusCode == 200){
        bool newUpdate=false;

        //get current local posts
        List<String> currPosts=List<String>();
        Database con= await dbTables.myProfileCon();
        List<Map> result= await con.rawQuery("select post_id from wall_posts");
        int curPostCount= result.length;
        for(int k=0; k<curPostCount; k++){
          currPosts.add(result[k]["post_id"]);
        }
        //con.execute("delete from wall_posts");
        
        //compare server data with local data
        var respObj= jsonDecode(resp.body);
        Directory myPostDir= Directory(_appdir.path + "/wall_dir/my_post_images");
        await myPostDir.create();
        String myPostDirPath= _appdir.path + "/wall_dir/my_post_images";

        http.Client client= http.Client();
        int kount= respObj.length;
        
        for(int k=0; k<kount; k++){
          String targPid=respObj[k]["id"];
          String targUrl=respObj[k]["url"];
          List<String> brkUrl= targUrl.split("/");
          String _fname=brkUrl.last;
          if(currPosts.indexOf(targPid)<0){
            newUpdate=true;
            await con.execute("insert into wall_posts (post_id, post_image) values (?, ?)", [targPid, _fname]);
            File tmpFile= File("$myPostDirPath/$_fname");
            http.Response tmpresp=await client.get(targUrl);
            await tmpFile.writeAsBytes(tmpresp.bodyBytes);
          }
        }
        if(newUpdate){
          getLocalPosts(callFromServerUpdate: true);
          client.close();
        }
      }
    }
    catch(ex){
      
    }
  }

  Widget pageBody(){
    return Container(
      child: LiquidPullToRefresh(
        color: Color.fromRGBO(26, 26, 26, 1),
        backgroundColor: Colors.white,
        height: 50,
        showChildOpacityTransition: false,
        child: ListView(
          controller: mainListCtr,
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(left:24, right:24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          child: dp,
                        ),
                        Container(
                          child: GestureDetector(
                            onTap: (){

                            },
                            child: Column(
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    postCount,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24
                                    ),
                                  ),
                                ),
                                Container(
                                  child: Text(
                                    "Posts",
                                    style: TextStyle(
                                      color: Colors.white
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),//postcount
                        Container(
                          child: GestureDetector(
                            onTap: (){

                            },
                            child: Column(
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    followerCount,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24
                                    ),
                                  ),
                                ),
                                Container(
                                  child: Text(
                                    "Followers",
                                    style: TextStyle(
                                      color: Colors.white
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),//followers count

                        Container(
                          child: GestureDetector(
                            onTap: (){

                            },
                            child: Column(
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    followingCount,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24
                                    ),
                                  ),
                                ),
                                Container(
                                  child: Text(
                                    "Following",
                                    style: TextStyle(
                                      color: Colors.white
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),//following count
                      ],
                    ),
                  ),//dp, postcount, follower and followingcount

                  Container(
                    margin: EdgeInsets.only(top: 12),
                    child: Text(
                      username,
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),//username
                  GestureDetector(
                    onTap: (){
                      if(profileWebTitle!="https://$profileWebsite"){
                        launchLink("https://$profileWebsite");
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top:9, bottom: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.blue
                        )
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 200,
                            padding: EdgeInsets.only(left:12, right: 12 , top:5, bottom: 5),
                            margin: EdgeInsets.only(bottom: 5),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(50, 50, 50, 1),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(7),
                                topRight: Radius.circular(7)
                              )
                            ),
                            child: Text(
                              profileWebTitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:Colors.white
                              )
                            ),
                          ),//page title
                          Container(
                            padding: EdgeInsets.only(top:3, bottom:3, left:12, right:12),
                            margin: EdgeInsets.only(bottom: 3, left:7, right:7),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(1, 1, 1, 1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey
                              )
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  margin: EdgeInsets.only(right:5),
                                  child: Icon(
                                    FlutterIcons.lock_ant,
                                    color: Colors.white
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    child: Text(
                                      "https://" + profileWebsite,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                      ),
                                    )
                                  )
                                )
                              ],
                            ),
                          ), //address bar
                          Container(
                            margin: EdgeInsets.only(left:7, right:7,bottom: 7, top: 5),
                            width: double.infinity,
                            padding: EdgeInsets.only(top:3, bottom: 3, left:7, right: 7),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(200, 200, 200, 200),
                              borderRadius: BorderRadius.circular(7)
                            ),
                            child: RichText(
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: <TextSpan>[
                                  (profileWebDescription!="") ?
                                  TextSpan(
                                    text: "$profileWebDescription",
                                    style: TextStyle(
                                      
                                    )
                                  ):
                                  TextSpan(
                                    text: profileWebTitle,
                                    style: TextStyle(
                                      fontSize: 18
                                    )
                                  )
                                ]
                              ),
                            ),
                          )//web content
                        ],
                      )
                    ),
                  ), //website
                  Container(
                    child: Text(
                      profileBrief,
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),//profile brief
                  Container(
                    width: MediaQuery.of(_pageContext).size.width - 10,
                    margin: EdgeInsets.only(top:12, bottom: 12),
                    child: RaisedButton(
                      padding: EdgeInsets.only(top:3, bottom: 3),
                      color: Colors.black,
                      textColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                        side: BorderSide(
                          color: Colors.grey
                        )
                      ),
                      onPressed: (){
                        Navigator.of(_pageContext).push(
                          MaterialPageRoute(
                            builder: (BuildContext ctx){
                              return EditWallProfile();
                            }
                          )
                        );
                      },
                      child: Text(
                        "EDIT PROFILE"
                      ),
                    ),
                  )
                ],
              ),
            ),//about me


            /*
              display posts and tags
            */
            Container(
              height: MediaQuery.of(_pageContext).size.height-70,
              padding: EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color.fromRGBO(20, 20, 20, 1)
                  )
                )
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: TabBar(
                      controller: postTagCtr,
                      indicatorColor: Color.fromRGBO(150, 150, 150, 1),
                      labelPadding: EdgeInsets.only(top:5, bottom: 9),
                      tabs: <Widget>[
                        Icon(
                          FlutterIcons.timeline_text_mco,
                          color: Colors.white,
                          size: 28,
                        ),
                        Icon(
                          FlutterIcons.bookmark_oct,
                          color: Colors.white,
                          size: 28,
                        )
                      ]
                    ),
                  ),//tabbar

                  Container(
                    height: MediaQuery.of(_pageContext).size.height - 200,
                    child: TabBarView(
                      controller: postTagCtr,
                      children: <Widget>[
                        localPosts,
                        localWallTags
                      ]
                    ),
                  )     
                ],
              ),
            )//display posts and tags
          ],
        ), 
        onRefresh: getLocalUData
      ),
    );
  }//pagebody

  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    return Scaffold(
      backgroundColor: Color.fromRGBO(26, 26, 26, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(20, 20, 20, 1),
        title: Text(
          globals.fullname,
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
      body: FocusScope(
        child: pageBody(),
        autofocus: true,
        onFocusChange: (curState){
          if(curState == true){
            if(firstLoad == false){
              fetchFromServer=true;
              getLocalUData();
            }
          }
        },
      )
    );
  }//page build

  @override
  void dispose() {
    super.dispose();
    mainListCtr.dispose();
    postTagCtr.dispose();
  }//page dispose
}