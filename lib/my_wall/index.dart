import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart' as urlLauncher;

import './add_mywall_post_dialog.dart';
import '../globals.dart' as globals;
import '../dbs.dart';
import './my_profile.dart';
import './post_comments.dart';

class MyWall extends StatefulWidget{
  _MyWall createState(){
    return _MyWall();
  }
}


class _MyWall extends State<MyWall> with SingleTickerProviderStateMixin{
  DBTables dbTables=DBTables();
  bool globDlgIsVisible=false;

  globals.KjToast _kjToast;

  Map<String, Map> postPPt= Map<String, Map>();
  
  StreamController dpChangedCtr= StreamController.broadcast();
  ///The stream controller for wall list view render changes
  StreamController wallRenderCtr= StreamController.broadcast();

  ///The scroll controller for the wall's primary list view
  ScrollController wallScrollCtr;
  StreamController pullRefreshCtr= StreamController.broadcast();
  convertToK(int val){
    List<String> units=["K", "M", "B"];
    double remain = val/1000;
    int counter=-1;
    if(remain>1) counter++;
    while(remain>999){
      counter++;
      remain /=1000;
    }
    if(counter>-1) return remain.toStringAsFixed(1) + units[counter];
    return "$val";
  }//convert to k m or b

  
  likeUnlikePost(String postId)async{
    try{
      String url=globals.globBaseUrl + "?process_as=like_wall_post";
      http.post(
        url,
        body: {
          "user_id": globals.userId,
          "post_id": postId,
        }
      );
    }
    catch(ex){
      showToast(
        text: "Like is disabled in offline mode",
        duration: Duration(seconds: 5)
      );
    }
  }//like unlike post
  RegExp _htag= RegExp(r"^#[a-z0-9_]+$", caseSensitive: false);
  RegExp _href= RegExp(r"[a-z0-9-]+\.[a-z0-9-]+", caseSensitive: false);
  RegExp _atTag= RegExp(r"^@[a-z0-9_]+$", caseSensitive: false);
  
  ///Tries to open a URL or a local link (an app link)
  followLink(String _link){
    if(_href.hasMatch(_link)){
      urlLauncher.canLaunch(_link).then((_canLaunch) {
        if(_canLaunch){
          urlLauncher.launch(_link);
        }
      });
    }
  }

  ///Adds or remove a post from bookmark list of wall posts
  Future bookmarkPost(String _postId)async{
    Database _con= await dbTables.wallPosts();
    _con.rawQuery("select book_marked from wall_posts where post_id=?", [_postId]).then((_queryResult) {
      if(_queryResult.length==1){
        if(_queryResult[0]["book_marked"] == "no"){
          _con.execute("update wall_posts set book_marked='yes' where post_id='$_postId'");
        }
        else{
          _con.execute("update wall_posts set book_marked='no' where post_id='$_postId'");
        }
      }
    });
  }

  Future<bool> postComment(String postId)async{
    if(_wallPostCommentCtr.containsKey(postId)){
      String _url= globals.globBaseUrl + "?process_as=post_wall_comment";
      TextEditingController _targetCtr=_wallPostCommentCtr[postId];
      if(_targetCtr.text == "") return false;
      try{
        String _postText=_targetCtr.text;
        _targetCtr.text="";
        http.Response resp= await http.post(
            _url,
            body: {
              "user_id": globals.userId,
              "post_id": postId,
              "reply_to": "",
              "post_text":_postText
            }
        );
        if(resp.statusCode == 200){
          if(resp.body == "success"){
            fetchPosts(caller: "init");
            return true;
          }
          else{
            showToast(
                text: "Can't comment - It seems you are logged out",
                duration: Duration(seconds: 3)
            );
            return false;
          }
        }
        else{
          showToast(
            text: "Can't comment now - try again later",
            duration: Duration(seconds: 3)
          );
          return false;
        }
      }
      catch(ex){
        showToast(
            text: "Can't comment - Offline mode",
            duration: Duration(seconds: 5)
        );
        return false;
      }
    }
    else return false;
  }

  Map<String, Map> pageViewCtrs=Map<String, Map>();

  int pseudoPgCtrAttach=0;
  var _serverData;
  bool refreshData=true;
  String postPos="0";
  

  Future<void> fetchPosts({String caller})async{
    bool resp= await fetchLocalData(caller: caller);
    if(resp){_kjToast.showToast(
      text: "Hello just tested the global toast",
      duration: Duration(seconds: 5)
    );
      renderWall();
    }
  }//fetch posts


  Widget _wallBlocks;
  double pullRefreshHeight=0;
  double pullRefreshLoadHeight=80;
  ///Renders the page with data from 'serverData' variable
  renderWall(){
    try{
      var _wallObj= _serverData;
      _wallBlocks= kjPullToRefresh(
        child: ListView.builder(
          controller: wallScrollCtr,
          cacheExtent: MediaQuery.of(_pageContext).size.height * 3,
          itemCount: _wallObj.length,
          itemBuilder: (BuildContext ctx, int itemIndex){
            if(itemIndex == 0){
              return Column(
                children: <Widget>[
                  pullToRefreshContainer(),
                  wallBlock(
                    blockIndex: itemIndex
                  ),
                  Container(
                    padding: EdgeInsets.only(top:12, bottom:12),
                    margin: EdgeInsets.only(top: 12, bottom: 12),
                    height: 250,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(40, 40, 40, 1)
                    ),
                    width: _screenSize.width,
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.only(left:12, right:12),
                          margin:EdgeInsets.only(bottom: 16),
                          child: Flex(
                            direction: Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Flexible(
                                flex:7,
                                child: Text(
                                  "Friends' suggestion",
                                  style: TextStyle(
                                    color: Colors.white
                                  ),
                                ),
                              ),
                              Flexible(
                                flex:3,
                                child: Container(
                                  alignment: Alignment.topRight,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkResponse(
                                      onTap: (){

                                      },
                                      child: Text(
                                        "See All",
                                        style: TextStyle(
                                            color: Colors.blue
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ), //suggested for you
                ],
              );
            }
            else{
              return wallBlock(
                  blockIndex: itemIndex
              );
            }
          }
        ),
      );
      wallRenderCtr.add(_wallBlocks);
    }
    catch(_ex){
    }
  }//render wall

  List<String> imageExts= ["jpg", "png", "gif"];
  List<String> videoExts= ["mp4"];
  Map<String, PageController> wallMediaPageCtr= Map<String, PageController>();
  Map<String, int> _wallPVCurPage= Map<String, int>();
  StreamController pageChangeNotifier= StreamController.broadcast();
  Map<String, VideoPlayerController> wallVideoCtr= Map<String, VideoPlayerController>();
  StreamController _vidVolCtrl= StreamController.broadcast();
  bool _globalMute=true;
  Map<String, bool> wallLikes=Map<String, bool>();
  StreamController wallLikeCtr= StreamController.broadcast();
  Map<String, bool> showMorePost=Map<String, bool>();
  StreamController showMorePostCtr= StreamController.broadcast();

  Map<String, String> _wallBooked=Map<String, String>();
  StreamController _wallBookedCtr= StreamController.broadcast();
  Map<String, int> _wallPostBlock= Map<String, int>();
  Map<String, TextEditingController> _wallPostCommentCtr= Map<String, TextEditingController>();

  ///A block in the wall
  Widget wallBlock({int blockIndex}){
    String _postDir= _appdir.path + "/wall_dir/post_media";
    var wallObj= _serverData;
    String postId= wallObj[blockIndex]["post_id"];
    wallMediaPageCtr["$postId"]=PageController();

    _wallPostBlock[postId]= blockIndex;

    if(!_wallPVCurPage.containsKey(postId)){
      _wallPVCurPage[postId]= 0;
    }
    wallMediaPageCtr["$postId"].addListener(() {
      double _localCurPage=wallMediaPageCtr[postId].page;
      if(_localCurPage.floor() == _localCurPage){
        if(wallMediaPageCtr[postId].hasClients){
            _wallPVCurPage[postId]=_localCurPage.toInt();
        }
        pauseAllVids();
        String _localVideoKey=postId + "." + _localCurPage.toInt().toString();
        if(wallVideoCtr.containsKey(_localVideoKey)){
          wallVideoCtr[_localVideoKey].play();
        }
        pageChangeNotifier.add("kjut");
      }
    });
    List postMedia= jsonDecode(wallObj[blockIndex]["post_images"]);
    List<Widget> pvChildren= List<Widget>();
    int mediaCount= postMedia.length;
    double _mediaAR= double.tryParse(postMedia[0]["ar"]);
    double pvHeight= _screenSize.width * (1/_mediaAR);
    for(int k=0; k<mediaCount; k++){
      String targMediaName=postMedia[k]["name"];
      List<String> brkMediaName= targMediaName.split(".");
      String mediaExt= brkMediaName.last;
      if(imageExts.indexOf(mediaExt)>-1){
        pvChildren.add(
          Container(
            width: _screenSize.width,
            child: Stack(
              children: <Widget>[
                Container(
                  width:_screenSize.width,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(_postDir + "/" + postMedia[k]["name"])),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft
                    )
                  ),
                )
              ],
            ),
          )
        );
      }
      else{
        String _tmpPlayerKey="$postId.$k";
        if(!wallVideoCtr.containsKey("$_tmpPlayerKey")) {
          wallVideoCtr["$_tmpPlayerKey"] = VideoPlayerController.file(File(_postDir + "/" + postMedia[k]["name"]));
          wallVideoCtr["$_tmpPlayerKey"].initialize().then((value) {
            wallVideoCtr["$_tmpPlayerKey"].setVolume(0);
            wallVideoCtr["$_tmpPlayerKey"].seekTo(Duration(milliseconds: 500));
            wallVideoCtr["$_tmpPlayerKey"].setLooping(true);
          });
        }
        pvChildren.add(
           Container(
             width: _screenSize.width,
             child: Stack(
               children: <Widget>[
                  Container(
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: AspectRatio(
                    aspectRatio: double.tryParse(postMedia[k]["ar"]),
                    child: VideoPlayer(
                        wallVideoCtr["$_tmpPlayerKey"]
                      ),
                    )
                  ), //Player container
                 Positioned(
                   right: 16, bottom: 12,
                   child: Material(
                     color: Colors.transparent,
                     child: InkResponse(
                       onTap: (){
                         if(_globalMute){
                           _globalMute=false;
                         }
                         else{
                           _globalMute=true;
                         }
                         _vidVolCtrl.add("kjut");
                         wallVideoCtr.forEach((key, value) {
                           if(_globalMute){
                             value.setVolume(0);
                           }
                           else value.setVolume(1);
                         });
                         },
                       child: StreamBuilder(
                         stream: _vidVolCtrl.stream,
                         builder: (BuildContext ctx, AsyncSnapshot snapshot){
                           return Icon(
                             (_globalMute) ?  FlutterIcons.volume_variant_off_mco : FlutterIcons.ios_volume_high_ion,
                             color: Colors.white,
                           );
                         },
                       ),
                     ),
                   ),
                 )
               ],
             ),
           ) 
        );
      }
    }
    String dp=wallObj[blockIndex]["dp"];

    List wallLikers= jsonDecode(wallObj[blockIndex]["likes"]);
    wallLikes["$postId"]= wallLikers.indexOf(globals.userId)>-1;

    _wallBooked["$postId"]= wallObj[blockIndex]["book_marked"];

    if(!showMorePost.containsKey(postId)){
      showMorePost[postId]=false;
    }

    List _wallComments= jsonDecode(wallObj[blockIndex]["comments"]);
    if(!_wallBlockKeys.containsKey(postId)){
      _wallBlockKeys[postId]= GlobalKey();
    }
    if(!_wallPostCommentCtr.containsKey(postId)){
      _wallPostCommentCtr[postId]=TextEditingController();
    }
    return Container(
      key: _wallBlockKeys[postId],
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[

          /*user dp, username and fullname
          */
          Container(
            margin: EdgeInsets.only(bottom: 9),
            padding: EdgeInsets.only(left: 12, right: 12),
            child: Row(
              children: <Widget>[
                Container(
                  margin: EdgeInsets.only(right:9),
                  child: dp.length == 1 ? 
                  CircleAvatar(
                    radius: _screenSize.width < 420 ? 15 : 20,
                    child: Text(
                      dp,
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ):
                  CircleAvatar(
                    radius: _screenSize.width < 420 ? 15 : 20,
                    backgroundImage: FileImage(File("$_postDir/$dp")),
                  ),
                ),//user dp
                Expanded(
                  child: Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        wallObj[blockIndex]["username"] =="" 
                        ?Container()
                        : Container(
                          margin: EdgeInsets.only(bottom:0),
                          child: Text(
                            wallObj[blockIndex]["username"],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _globalFontSize,
                              fontWeight: FontWeight.bold
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),//username if it exists
                        Container(
                          child: Text(
                            wallObj[blockIndex]["fullname"],
                            style: TextStyle(
                              color:Colors.white,
                              fontSize: _globalFontSize
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ],
                    ),
                  )
                )//user name and fullname
              ],
            ),
          ), // user dp username, full name


          /*The uploaded media
          */
          Container(
            height: pvHeight,
            child: PageView(
              pageSnapping: true,
              controller: wallMediaPageCtr["$postId"],
              children: pvChildren,
            ),
          ),//the uploaded media


          /* like comment share dots and book mark
          */
          Container(
            padding: EdgeInsets.only(left:12, right:12, top:9, bottom: 9),
            child: Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  flex: 4,
                  child: Row(
                    children: <Widget>[
                      StreamBuilder(
                        stream: wallLikeCtr.stream,
                        builder: (BuildContext ctx, AsyncSnapshot snapshot){
                          return Material(
                            color: Colors.transparent,
                            child: InkResponse(
                              onTap: (){
                                wallLikes["$postId"] = !(wallLikes["$postId"]);
                                wallLikeCtr.add("kjut");
                                likeUnlikePost(postId);
                              },
                              child: wallLikes["$postId"] ? 
                                ScaleTransition(
                                  scale: _likeAni,
                                  child: Icon(
                                    FlutterIcons.ios_heart_ion,
                                    color: Colors.white,
                                  ),
                                ):
                                Icon(
                                  FlutterIcons.ios_heart_empty_ion,
                                  color: Colors.white,
                                )
                            ),
                          );
                        }
                      ),//like icon

                      Container(
                        margin: EdgeInsets.only(
                          left: _screenSize.width < 420 ? 9 : 12,
                          right: _screenSize.width < 420 ? 9 : 12
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkResponse(
                            onTap: (){
                              pauseAllVids();
                              Navigator.push(
                                  _pageContext,
                                  MaterialPageRoute(
                                      builder: (BuildContext _navPushCtx){
                                        return ViewPostedComments(postId);
                                      }
                                  )
                              );
                            },
                            child: Icon(
                              FlutterIcons.commenting_o_faw,
                              color: Colors.white,
                            ),
                          )
                        ),
                      ),// comment Icon

                      Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          child: Icon(
                            FlutterIcons.send_faw,
                            color:Colors.white
                          ),
                        ),
                      ), //send icon

                    ],
                  ),
                ),//left container

                Flexible(
                  flex: 5,
                  child: Container(
                    child: StreamBuilder(
                      stream: pageChangeNotifier.stream,
                      builder: (BuildContext ctx, AsyncSnapshot snapshot){
                        List<Widget> pageDots= List<Widget>();
                        for(int k=0; k<mediaCount; k++){
                          bool isCurPage= _wallPVCurPage[postId] == k;
                          pageDots.add(
                            AnimatedContainer(
                              margin: EdgeInsets.only(right: 3),
                              duration: Duration(milliseconds: 300),
                              width: isCurPage ? 7 : 4, 
                              height: isCurPage ? 7 : 4,
                              decoration: BoxDecoration(
                                color: isCurPage ? Colors.blue : Colors.white,
                                borderRadius: isCurPage ? BorderRadius.circular(16) : BorderRadius.circular(0)
                              ),
                            )
                          );
                        }
                        if(mediaCount>1){
                          return Row(
                            children: pageDots
                          );
                        }
                        else{
                          return Container();
                        }
                      }
                    ),
                  )
                ),// dots

                Flexible(
                  flex: 1,
                  child: Container(
                    child: Material(
                      color: Colors.transparent,
                      child: InkResponse(
                        onTap: (){
                          bookmarkPost(postId);
                          _wallBooked["$postId"] == "no" ? _wallBooked["$postId"] = "yes" : _wallBooked["$postId"] = "no";
                          _wallBookedCtr.add("kjut");
                        },
                        child: StreamBuilder(
                          stream: _wallBookedCtr.stream,
                          builder: (BuildContext ctx, AsyncSnapshot snapshot){
                            return Icon(
                              _wallBooked["$postId"] == "no" ? FlutterIcons.bookmark_o_faw : FlutterIcons.bookmark_faw,
                              color: Colors.white,
                            );
                          }
                        ),
                      ),
                    ),
                  )
                )
              ],
            ),
          ),//like, comment, share, dots, bookmark

          /*count likes
          */
          Container(
            padding: EdgeInsets.only(left:12, right:12),
            child: Row(
              children: <Widget>[
                Container(
                  child: Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      onTap: (){
                        
                      },
                      child: Text(
                        wallLikers.length==1 ? "1 like" : convertToK(wallLikers.length) + " likes",
                        style: TextStyle(
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ), //count likes


          /*Post  text
          */
          Container(
            padding: EdgeInsets.only(left:12, right:12),
            margin: EdgeInsets.only(top:3),
            child: StreamBuilder(
              stream: showMorePostCtr.stream,
              builder: (BuildContext ctx, AsyncSnapshot snapshot){
                String _postText=wallObj[blockIndex]["post_text"];
                if(_screenSize.width<420){
                  if(_postText.length > 90 && showMorePost[postId] == false){
                    _postText = _postText.substring(0, 90) + "...";
                  }
                  else showMorePost[postId]=true;
                }
                else{
                  if(_postText.length > 200 && showMorePost[postId]==false){
                    _postText = _postText.substring(0, 200) + "...";
                  }
                  else showMorePost[postId]=true;
                }
                List<String> _brkPostText= _postText.split(" ");
                int _brkPostTextCount= _brkPostText.length;
                List<InlineSpan> _postTextSpan= List<InlineSpan>();
                String _curPostText="";
                for(int _j=0; _j<_brkPostTextCount; _j++){
                  String _curText=_brkPostText[_j];
                  if(_htag.hasMatch(_curText) || _atTag.hasMatch(_curText) || _href.hasMatch(_curText)){
                    _postTextSpan.add(
                        TextSpan(
                          text: "$_curPostText ",
                        )
                    );
                    _curPostText="";
                    _postTextSpan.add(
                        TextSpan(
                            text: "$_curText ",
                            style: TextStyle(
                                color: (_href.hasMatch(_curText)) ? Colors.blue : Colors.blueGrey
                            ),
                            recognizer: TapGestureRecognizer()..onTap=(){
                              followLink(_curText);
                            }
                        )
                    );
                  }
                  else{
                    _curPostText += "$_curText ";
                  }
                }
                _postTextSpan.add(
                  TextSpan(
                    text: _curPostText
                  )
                );
                return RichText(
                    text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                              children: _postTextSpan,
                              recognizer: TapGestureRecognizer()..onTap=(){
                                if(showMorePost[postId] == false){
                                  showMorePost[postId]=true;
                                  showMorePostCtr.add("kjut");
                                }
                              }
                          ),
                          (showMorePost.containsKey(postId) && showMorePost[postId]) ? TextSpan()
                              : TextSpan(
                              text: " more",
                              style: TextStyle(
                                  color: Colors.grey
                              ),
                              recognizer: TapGestureRecognizer()..onTap=(){
                                showMorePost[postId]=true;
                                showMorePostCtr.add("kjut");
                              }
                          )
                        ]
                    )
                );
              },
            ),
          ),//Post text


          /*
          Comment Count
          * */
          Container(
            margin: EdgeInsets.only(top: 7, bottom:7),
            padding: EdgeInsets.only(left:12, right:12),
            child: GestureDetector(
              onTap: (){
                Navigator.push(
                    _pageContext,
                    MaterialPageRoute(
                      builder: (BuildContext _navPushCtx){
                        return ViewPostedComments(postId);
                      }
                    )
                );
              },
              child: Text(
                  _wallComments.length>0 ? "${_wallComments.length} comments, view" : "No comments",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: _globalFontSize
                ),
              ),
            ),
          ),//Comment Count

          /*Add new comments
          * */
          Container(
            padding: EdgeInsets.only(left:12, right:12),
            child: Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  flex: 2,
                  child: Container(
                    margin: EdgeInsets.only(right:7),
                    child: _wallDp,
                  ),
                ),//User dp

                Flexible(
                  flex: 6,
                  child: Container(
                    margin: EdgeInsets.only(right:12),
                    child: TextField(
                      controller: _wallPostCommentCtr[postId],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _globalFontSize
                      ),
                      decoration: InputDecoration(
                        hintText: "Comment as " + globals.fullname,
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: _globalFontSize
                        )
                      ),
                    )
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: RaisedButton(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)
                      ),
                      padding: EdgeInsets.only(top:2, bottom:2, right:12, left:12),
                      elevation: 0,
                      color: Color.fromRGBO(36, 36, 36, 1),
                      onPressed: (){
                        postComment(postId);
                      },

                      child:Text(
                        "Comment",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.fromRGBO(49, 108, 197, 1)
                        ),
                      )
                    ),
                  )
                )
              ],
            ),
          ), //Add new comments

          /*Post time
          * */
          Container(
            padding: EdgeInsets.only(left:12, right:12),
            margin: EdgeInsets.only(top:3),
            child: Text(
              wallObj[blockIndex]["time_str"],
              style: TextStyle(
                color: Colors.grey,
                fontSize: _globalFontSize
              ),
            ),
          )//post time

        ],
      ),
    );
  }//wall block

  ///This is the container placed as the first child of the listview
  ///to show a pull-to-refresh cue
  Widget pullToRefreshContainer(){
    return StreamBuilder(
            stream: pullRefreshCtr.stream,
            builder: (BuildContext ctx, AsyncSnapshot snapshot){
              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                height: pullRefreshHeight,
                color: Color.fromRGBO(30, 30, 30, 1),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      bottom: pullRefreshHeight - pullRefreshLoadHeight - 20,
                      child: Container(
                        alignment: Alignment.center,
                        child: Container(
                          width: 50, height: 50,
                          alignment: Alignment.center,
                          child: pullRefreshHeight< pullRefreshLoadHeight ? 
                          CircularProgressIndicator(
                            value: pullRefreshHeight/pullRefreshLoadHeight,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            strokeWidth: 3,
                          ):
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            strokeWidth: 3,
                          )
                      ),
                        )
                    )
                  ],
                ),
              );
            },
          );
  }//pull to refresh container

  ///Pass a listview as child widget to this widget
  Widget kjPullToRefresh({Widget child}){
    return Listener(
      behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent pue){
          if(pullRefreshHeight< pullRefreshLoadHeight){
            pullRefreshHeight =0;
            pullRefreshCtr.add("kjut");
          }
          else{
            Future.delayed(
              Duration(milliseconds: 1500),
              (){
                //call the refresh function
                pullRefreshHeight=0;
                pullRefreshCtr.add("kjut");
                fetchPosts(caller: "init");
              }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(wallScrollCtr.position.atEdge && !_delta.direction.isNegative){
            double dist= math.sqrt(_delta.distanceSquared);
            if(pullRefreshHeight <pullRefreshLoadHeight){
              pullRefreshHeight +=(dist/3);
              pullRefreshCtr.add("kjut");
            }
            else{
              debugPrint("Time to hit refresh");
            }
          }
        },
        child: child
      );
  }//kjut pull to refresh

  ///Get's local data before updating with server data
  Future<bool> fetchLocalData({String caller}) async{
    Database con= await dbTables.wallPosts();
    var result=await con.rawQuery("select * from wall_posts where status='complete' order by cast(post_id as unsigned) desc");

    _serverData= result;
    if(caller == "init"){
      refreshWall();
    }
    if(result.length<1){
      return false;
    }
    return true;
  }

  ///Get fresh contents from server or from database
  ///Updates the database with fresh server contents if it exists
  Future<void> refreshWall()async{
    String _url=globals.globBaseUrl + "?process_as=fetch_wall_post";
    try{
      http.Response _resp= await http.post(
        _url,
        body: {
          "user_id": globals.userId,
          "start" : postPos
        }
      );
      if(_resp.statusCode == 200){
        RegExp _vidFExp= RegExp(r"\.mp4$", caseSensitive: false);
        //let's get existing posts
        Database _con= await dbTables.wallPosts();
        var _result= await _con.rawQuery("select post_id from wall_posts where status='complete'");
        List<String> _pids=List<String>();
        int _resultCount=_result.length;
        
        for(int _k=0; _k<_resultCount; _k++){
          _pids.add(
            _result[_k]["post_id"]
          );
        }
        var _respObj= jsonDecode(_resp.body);
        int _kount= _respObj.length;
        
        Directory _wallDir= Directory(_appdir.path + "/wall_dir");
        await _wallDir.create();
        Directory _postDir= Directory(_wallDir.path + "/post_media");
        await _postDir.create();
        for(int _k=0; _k<_kount; _k++){
          String _serverImageDir= _respObj[_k]["image_path"];
          var _targPID= _respObj[_k]["post_id"];
          if(_pids.indexOf(_targPID)<0){
            //new post item from server or probably an old post that was not processed to completion due errors - videoplayer error

            //check that this post does was not present before
            var _checkPostResult= await _con.rawQuery("select * from wall_posts where post_id='$_targPID'");
            if(_checkPostResult.length==1){
              var _checkPostImages=jsonDecode(_checkPostResult[0]["post_images"]);
              int _checkPostImagesCount= _checkPostImages.length;
              for(int _j=0; _j<_checkPostImagesCount; _j++){
                String _checkPostImagePath= _postDir.path + "/" + _checkPostImages[_j]["name"];
                File _checkPostImageFile=File(_checkPostImagePath);
                _checkPostImageFile.exists().then((_fexists){
                  if(_fexists){
                    _checkPostImageFile.delete();
                  }
                });
              }
              await _con.execute("delete from wall_posts where post_id='$_targPID'");
              return;
            }

            List<Map<String, String>> _postImages= List<Map<String, String>>();
            var _serverPImages= _respObj[_k]["images"];
            int _imageCount= _serverPImages.length;
            for(int _j=0; _j<_imageCount; _j++){
              String _localAR= "auto";
              if(_j == 0){
                String _firstMediaAR=_respObj[_k]["ar"];
                if(_firstMediaAR=="auto"){
                  _localAR="auto";
                }
                else{
                  List<String> _brkServerMediaAR= _firstMediaAR.split("/");
                  double _calcMediaAR= double.tryParse(_brkServerMediaAR[0]) / double.tryParse(_brkServerMediaAR[1]);
                  _localAR= _calcMediaAR.toString();
                }
              }
              _postImages.add({
                "name": _serverPImages[_j],
                "ar": _localAR
              });
            }
            String _jsonPostImages= jsonEncode(_postImages);

            String _status="pending";
            String _uid=_respObj[_k]["user_id"];
            String _postText=_respObj[_k]["post_text"];
            String _views= jsonEncode(_respObj[_k]["views"]);
            String _time=_respObj[_k]["post_time"];
            String _likes=jsonEncode(_respObj[_k]["likes"]);
            String _comments=jsonEncode(_respObj[_k]["comments"]);
            String _linkTo=_respObj[_k]["link_to"];
            String _bookmarked="no";
            String _mediaServerLoc= _respObj[_k]["image_path"];
            String _postDP=_respObj[_k]["dp"];
            if(_postDP.length>1){
              String _postDPURL="$_postDP";
              List<String> _brkPostDP= _postDP.split("/");
              _postDP= DateTime.now().millisecondsSinceEpoch.toString() + _brkPostDP.last;
              http.readBytes(_postDPURL).then((_postDPBytesData){
                File(_postDir.path + "/$_postDP").writeAsBytes(_postDPBytesData);
              });
            }
            String _username=_respObj[_k]["username"];
            String _fullname=_respObj[_k]["fullname"];
            _con.execute(
              "insert into wall_posts (post_id, user_id, post_images, post_text, views, time_str, likes, comments, post_link_to, status, book_marked, media_server_loc, dp, username, fullname) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
              [_targPID, _uid, _jsonPostImages, _postText, _views, _time, _likes, _comments, _linkTo, _status, _bookmarked, _mediaServerLoc, _postDP, _username, _fullname]
            );
            //delete the oldest post if local post count reaches the set threshold
            var _locResult= await _con.rawQuery("select id from wall_posts");
            if(_locResult.length >=_kount){
              var _oldestPostResult= await _con.rawQuery("select * from wall_posts where book_marked='no' order by post_id asc limit 1");
              if(_oldestPostResult.length == 1){
                  var _oldestPostImages=jsonDecode(_oldestPostResult[0]["post_images"]);
                  int _oldestPostImageCount= _oldestPostImages.length;
                  for(int _u=0; _u<_oldestPostImageCount; _u++){
                    File _oldestPostImage = File(_postDir.path + "/" + _oldestPostImages[_u]["name"]);
                    _oldestPostImage.exists().then((value) {
                      if(value) _oldestPostImage.delete();
                    });
                  }
                  String _oldestPDP= _oldestPostResult[0]["dp"];
                  File _oldestPDPF= File(_postDir.path + "/$_oldestPDP");
                  _oldestPDPF.exists().then((_foundDp){
                    if(_foundDp) _oldestPDPF.delete();
                  });
                  int _oldestPostId= _oldestPostResult[0]["id"];
                  _con.execute("delete from wall_posts where id=?", [_oldestPostId]);
              }
            }

            //now fetch post media
            for(int _j=0; _j<_imageCount; _j++){
              try{
                String _imageURL=_serverImageDir + "/" + _serverPImages[_j];
                http.get(_imageURL).then((_resp){
                  Uint8List _imageBytes=_resp.bodyBytes;
                  File _localImage= File(_postDir.path + "/" + _serverPImages[_j]);
                  _localImage.writeAsBytes(_imageBytes).then((_imageByteFile)async{
                    List<String> _brkImageName= _serverPImages[_j].toString().split(".");
                    if(videoExts.indexOf(_brkImageName.last) >-1){
                      VideoPlayerController _tmpVidCtr= VideoPlayerController.file(_imageByteFile);
                      _tmpVidCtr.initialize().then((value) async {
                        double _tmpvidAR= _tmpVidCtr.value.aspectRatio;
                        _tmpVidCtr.dispose();
                        var _innerTmpResult= await _con.rawQuery("select post_images from wall_posts where post_id='$_targPID'");
                        if(_innerTmpResult.length==1){
                          List _innerTmpMedia= jsonDecode(_innerTmpResult[0]["post_images"]);
                          int _countInnerTmpMedia= _innerTmpMedia.length;
                          for(int _t=0; _t<_countInnerTmpMedia; _t++){
                            if(_innerTmpMedia[_t]["name"] == _serverPImages[_j]){
                              _innerTmpMedia[_t]["ar"]= _tmpvidAR.toString();
                              String _innerMediaJson= jsonEncode(_innerTmpMedia);
                              bool _allVidsAR= true;
                              for(int _i=0; _i<_countInnerTmpMedia; _i++){
                                if(_vidFExp.hasMatch(_innerTmpMedia[_i]["name"])){
                                  if(_innerTmpMedia[_i]["ar"] == "auto"){
                                    _allVidsAR=false;
                                  }
                                }
                                if(File(_postDir.path + "/" + _innerTmpMedia[_i]["name"]).existsSync() == false){
                                  _allVidsAR=false;
                                }
                              }
                              if(_allVidsAR){
                                String _newInnerStatus="complete";
                                await _con.execute("update wall_posts set post_images=?, status=? where post_id=?", [_innerMediaJson, _newInnerStatus,  _targPID]);
                                fetchPosts();
                              }
                              else _con.execute("update wall_posts set post_images=? where post_id=?", [_innerMediaJson, _targPID]);
                              break;
                            }
                          }
                        }
                      });
                    }
                    else{
                      //then an image have been written successfully
                      var _innerTmpResult= await _con.rawQuery("select post_images from wall_posts where post_id='$_targPID'");
                      bool _allVidsAR= true;
                      if(_innerTmpResult.length==1){
                        List _innerTmpMedia= jsonDecode(_innerTmpResult[0]["post_images"]);
                        int _countInnerTmpMedia= _innerTmpMedia.length;
                        for(int _t=0; _t<_countInnerTmpMedia; _t++){
                          if(_vidFExp.hasMatch(_innerTmpMedia[_t]["name"])){
                            if(_innerTmpMedia[_t]["ar"] == "auto"){
                              _allVidsAR=false;
                            }
                          }
                          if(File(_postDir.path + "/" + _innerTmpMedia[_t]["name"]).existsSync() == false){
                            _allVidsAR=false;
                          }
                        }
                      }
                      if(_allVidsAR){
                        String _newInnerStatus="complete";
                        await _con.execute("update wall_posts set status=? where post_id=?", [_newInnerStatus,  _targPID]);
                        fetchPosts();
                      }
                    }
                  });
                });
              }
              catch(ex){

              }
            }
          }
          else{
            //update the views and the likes, ...
            String _views= jsonEncode(_respObj[_k]["views"]);
            String _likes=jsonEncode(_respObj[_k]["likes"]);
            String _comments=jsonEncode(_respObj[_k]["comments"]);
            String _postTime=_respObj[_k]["post_time"];
            await _con.execute("update wall_posts set views=?, likes=?, comments=?, time_str=? where post_id=?", [_views, _likes, _comments, _postTime, _targPID]);
            fetchPosts();
          }
        }
      }
      else{
        //server error
      }
    }
    catch(ex){
      showToast(
        text: "Offline mode - get connected for updated contents",
        duration: Duration(seconds: 3)
      );
      return false;
    }
  }//refresh wall


  BuildContext _pageContext;
  Widget pageBody(){
    return Scaffold(
      bottomNavigationBar:
        Container(
          padding: (_screenSize.width < 365) ? EdgeInsets.only(left: 22, right: 22) : EdgeInsets.only(left: 32, right: 32),
          decoration: BoxDecoration(
            color: Color.fromRGBO(26, 26, 26, 1)
          ),
          width: MediaQuery.of(_pageContext).size.width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){

                    },
                    child: Container(
                      width: 60, height: 60,
                      child: Icon(
                        FlutterIcons.home_ant,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                  ),
                ),
              ),//home button

              Container(
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){
                      showModalBottomSheet(
                        context: _pageContext,
                        backgroundColor: Color.fromRGBO(1, 1, 1, 1),
                        enableDrag: true,
                        isScrollControlled: true,
                        builder: (BuildContext ctx){
                          return GestureDetector(
                            onVerticalDragStart: (dragDetails){

                            },
                            child: NewWallPostDlg(),
                          );
                        }
                      );
                    },
                    child: Container(
                      width: 60, height: 60,
                      child: Icon(
                        FlutterIcons.ios_add_circle_ion,
                        color: Colors.white,
                        size: 28,
                      )
                    )
                  ),
                ),
              ),//add post

              Container(
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: (){

                    },
                    child: Container(
                      width: 60, height: 60,
                      child: Icon(
                        FlutterIcons.searchengin_faw5d,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                  ),
                ),
              ),//search

              StreamBuilder(
                stream: dpChangedCtr.stream,
                builder: (BuildContext ctx, AsyncSnapshot snapshot){
                  return _wallDp;
                }
              )
            ],
          ),
        ),//bottom navigation bar
      
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(26, 26, 26, 1),
        title: Container(
          padding: EdgeInsets.only(left:12),
          child: Text(
            "MY WALL",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        )
      ),
      body: FocusScope(
        child: Container(
          child: Stack(
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(top:16),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(1, 1, 1, 1)
                ),
                child: StreamBuilder(
                  stream: wallRenderCtr.stream,
                  builder: (BuildContext ctx, AsyncSnapshot snapshot){
                    if(snapshot.hasData){
                      return snapshot.data;
                    }
                    else{
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }
                  }
                ),
              ),//the page's actual content

              _kjToast
            ],
          ),
        ),//page container,
        autofocus: true,
        onFocusChange: (stat){
          if(stat){
            //capturing only when focus is gained
            if(_serverData!=null){
              initLocalWallDir();
              fetchPosts(caller: "init");
            }
          }
        },
      ),
      
    );
  }//pagebody
  StreamController toastCtrl=StreamController.broadcast();
  ///Mimics the native android toast
  showToast({String text, Duration duration}){
    toastCtrl.add({
      "visible": true,
      "text": text,
      "duration": duration
    });
  }//show toast

  ///Convenient method to pause all playing videos
  pauseAllVids(){
    wallVideoCtr.forEach((key, value) {
      if(value.value.isPlaying) value.pause();
    });
  }

  final Map<String, GlobalKey> _wallBlockKeys= Map<String, GlobalKey>();
  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  @override
  void initState() {
    super.initState();
    wallScrollCtr= ScrollController();
    wallScrollCtr.addListener(() {
      List<String> _currentlyVisible=List<String>();
      _wallBlockKeys.forEach((key, value) {
        if(value.currentContext!=null){
          RenderBox _tmpRb= value.currentContext.findRenderObject();
          Size _tmpSize= _tmpRb.size;
          Offset _tmpOffset= _tmpRb.localToGlobal(Offset.zero);
          //if(_tmpOffset.dy>0 && (_tmpOffset.dy + _tmpSize.height)< _screenSize.height){
          if(_tmpOffset.dy>(-.5 * _tmpSize.height) && _tmpOffset.dy<_screenSize.height){
            _currentlyVisible.add(key);
          }
        }
        else {
          //because we are using listview.builder, all elements are not always rendered
          //to save memory, and all that. So, depending on the cache extent that I have requested
          //some of the wall blocks may be nullified at points outside the cache extents
          //that I have specified. This else block takes care of that to avoid errors
        }
      });
      List<String> _visibleVids= List<String>();
      int _countCurVisible= _currentlyVisible.length;
      String _targKey="";
      for(int _k=0; _k<_countCurVisible; _k++){
        _targKey= _currentlyVisible[_k];
        String _locCurrentPage= _wallPVCurPage[_targKey].toString();
        if(wallVideoCtr.containsKey("$_targKey.$_locCurrentPage")){
          _visibleVids.add("$_targKey.$_locCurrentPage");
        }
      }
      if(_visibleVids.length<1){
        pauseAllVids();
      }
      if(_visibleVids.length>2){
        String _vidKey=_visibleVids[1];
        wallVideoCtr.forEach((key, value) {
          if(key!=_vidKey){
            if(value.value.isPlaying) value.pause();
          }
        });
        if(!wallVideoCtr[_vidKey].value.isPlaying)
        wallVideoCtr[_vidKey].play();
      }
      else if(_visibleVids.length>0){
        String _vidKey=_visibleVids[0];
        wallVideoCtr.forEach((key, value) {
          if(key!=_vidKey){
            if(value.value.isPlaying) value.pause();
          }
        });
        if(!wallVideoCtr[_vidKey].value.isPlaying)
          wallVideoCtr[_vidKey].play();
      }
    });
    fetchPosts(caller: "init");
    initLocalWallDir();

    _likeAniCtr= AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _likeAni= Tween(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
      parent: _likeAniCtr, 
      curve: Curves.elasticOut
    ));
    _likeAniCtr.repeat(
      reverse: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _kjToast = globals.KjToast(_globalFontSize, _screenSize, toastCtrl);
    });
  }

  Directory _appdir;
  Widget _wallDp= Container();
  initLocalWallDir()async{
    if(_appdir == null){
      _appdir= await getApplicationDocumentsDirectory();
      Directory wallDir= Directory(_appdir.path + "/wall_dir");
      await wallDir.create();

      _wallDp= Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: (){
            Navigator.of(_pageContext).push(MaterialPageRoute(
              builder: (BuildContext ctx){
                return MyWallProfile();
              }
            ));
          },
          child: Container(
            child: CircleAvatar(
              radius: 20,
              child: Text(
                globals.fullname.substring(0,1)
              ),
            ),
          ),
        ),
      );
    }
    
    

    Database con= await dbTables.myProfileCon();
    var _result= await con.rawQuery("select * from user_profile where status='active'");
    if(_result.length==1){
      var _rw= _result[0];
      String _dppath= _appdir.path + "/wall_dir/" + _rw["dp"];
      File _walldpF= File(_dppath);
       if(await _walldpF.exists()){
         _wallDp= Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: (){
                Navigator.of(_pageContext).push(MaterialPageRoute(
                  builder: (BuildContext ctx){
                    return MyWallProfile();
                  }
                ));
              },
              child: Container(
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: FileImage(_walldpF),
                ),
              ),
            ),
          );
       }
    }
    else{
      //create a new local profile
      String upStattus="active";
      String upname="";
      String profiledp="", upbrief="", upwebsite="", uppostcount="0", upfollower="0", upfollowing="0";
      String uprofileWebsiteTitle="", uprofileWebsiteDescription="";
      con.execute("insert into user_profile (username, dp, website, brief, post_count, follower, following, website_title, website_description, status) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",[upname, profiledp, upwebsite, upbrief, uppostcount, upfollower, upfollowing, uprofileWebsiteTitle, uprofileWebsiteDescription, upStattus]);
    }
    dpChangedCtr.add("kjut");
  }//init local wall dir

  Size _screenSize;
  double _globalFontSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_screenSize.width> 420) _globalFontSize=14;
    else _globalFontSize=13;
    return WillPopScope(
      child: MaterialApp(
        home: pageBody(),
      ),
      onWillPop: ()async{
        if(globDlgIsVisible){
          globDlgIsVisible=false;
        }
        else{
          Navigator.of(_pageContext).pop();
        }
        return false;
      }
    );
  }//page build method

  ///Closes all stream controllers
  closeAllStream(){
    dpChangedCtr.close();
    wallRenderCtr.close();
    pullRefreshCtr.close();
    wallLikeCtr.close();
    toastCtrl.close();
    pageChangeNotifier.close();
    showMorePostCtr.close();
    _wallBookedCtr.close();
    _vidVolCtrl.close();
  }//close all stream

  @override
  void dispose() {
    closeAllStream();
    wallScrollCtr.dispose();
    wallMediaPageCtr.forEach((key, value) {
      value.dispose();
    });
    wallVideoCtr.forEach((key, value) {
      if(value.value.isPlaying){
        value.pause();
      }
      value.dispose();
    });
    _wallPostCommentCtr.forEach((key, value) {
      value.dispose();
    });
    _likeAniCtr.stop();
    _likeAniCtr.dispose();
    super.dispose();
  }
}