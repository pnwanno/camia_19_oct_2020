import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart' as urlLauncher;
import 'package:flutter_icons/flutter_icons.dart';

import '../dbs.dart';
import '../globals.dart' as globals;

class ViewPostedComments extends StatefulWidget{
  _PostComments createState(){
    return _PostComments();
  }
  final String _gPostID;
  ViewPostedComments(this._gPostID);
}

class _PostComments extends State<ViewPostedComments> with SingleTickerProviderStateMixin{
  bool _pageDlg=false;
  StreamController _pageStreamCtr= StreamController.broadcast();
  DBTables dbTables= DBTables();
  Directory _appDir;
  Directory _wallDir;

  AnimationController _likeAniCtr;
  Animation<double> _likeAni;
  initState(){
    super.initState();
    initWallDir();
    fetchPostComments();
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
  }//route's init state

  initWallDir()async{
    _appDir=await getApplicationDocumentsDirectory();
    _wallDir=Directory(_appDir.path + "/wall_dir");
  }

  var _commentBlockData;
  Future<void> fetchPostComments()async{
    Database _con= await dbTables.wallPosts();
    String _locPostId= widget._gPostID;
    var _result= await _con.rawQuery("select * from wall_posts where post_id=?", [_locPostId]);
    if(_result.length == 1){
      _commentBlockData= _result;
      _pageStreamCtr.add("kjut");
    }
  }//fetch post comments

  ///Updates the local database with the updates on the current post
  Future refreshPost()async{
    try{
      String _url=globals.globBaseUrl + "?process_as";
      http.post(
        _url,
        body: {
          "post_id": widget._gPostID
        }
      ).then((_resp)async{
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          Database _con= await dbTables.wallPosts();
          String _postTime= _respObj["post_time"];
          String _postLikes= jsonEncode(_respObj["likes"]);
          String _postComments= jsonEncode(_respObj["comments"]);
          String _localPostID= widget._gPostID;
          _con.execute("update wall_posts set likes=?, comments, time_str where post_id=?", [
            _postLikes, _postComments, _postTime, _localPostID
          ]);
        }
      });
    }
    catch(ex){

    }
  }

  likeComment(String _commentId){
    try{
      String _url= globals.globBaseUrl + "?process=like_wall_comment";
      http.post(
        _url,
        body: {
          "post_id": widget._gPostID,
          "comment_id": _commentId,
          "user_id": globals.userId
        }
      );
    }
    catch(ex){

    }
  }

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
  
  dispose(){
    super.dispose();
    _pageStreamCtr.close();
    pullRefreshCtr.close();
    _commentLikeCtr.close();
    _likeAniCtr.dispose();
    _globalListCtr.dispose();
  }//route's dispose

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

  ///Processes a text and extracts supported links
  parseTextForLinks(String _textData){
    List<String> _brkPostText= _textData.split(" ");
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
          text: "$_curPostText"
        )
    );
    return _postTextSpan;
  }//parse text for links

  Future fetchImage(String imageURl) async{
    try{
      http.Response resp= await http.get(
        imageURl
      );
      if(resp.statusCode == 200){
        return resp.bodyBytes;
      }
    }
    catch(ex){
      return false;
    }
  }

  StreamController _commentLikeCtr= StreamController.broadcast();
  Widget commentBlock(List<Map> _commentLi, int itemIndex){
    List _commentLikes= jsonDecode(_commentLi[itemIndex]["likes"]);
    int _countLikes= _commentLikes.length;
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            child: Container(
              width: 32, height: 32,
              child: _commentLi[itemIndex]["dp"].toString().length == 1?
              CircleAvatar(
                radius: 24,
                child: Text(
                  _commentLi[itemIndex]["dp"],
                  style: TextStyle(

                  ),
                ),
              ):
              FutureBuilder(
                future: fetchImage(_commentLi[itemIndex]["dp"]),
                builder: (BuildContext ctx, snapshot){
                  if(snapshot.hasData && snapshot.data!=false){
                    return CircleAvatar(
                      radius: 24,
                      backgroundImage: MemoryImage(
                          snapshot.data
                      ),
                    );
                  }
                  else{
                    return CircleAvatar(
                      radius: 24,
                      child: Text(
                          "?"
                      ),
                    );
                  }
                },
              ),
            ),
          ), //dp

          Expanded(
            child: Container(
              margin: EdgeInsets.only(left:12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(bottom: 3),
                    child: Text(
                      _commentLi[itemIndex]["username"],
                      style: TextStyle(
                          color: Colors.blueGrey
                      ),
                    ),
                  ),//comment username

                  Container(
                    child: RichText(
                      text: TextSpan(
                          children: parseTextForLinks(_commentLi[itemIndex]["text"])
                      ),
                    ),
                  ), //comment

                  Container(
                    child: Wrap(
                      children: <Widget>[
                        Container(
                          child: Container(
                            child: Text(
                              _commentLi[itemIndex]["time"],
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 9
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),//comment time

                        Container(
                          margin: EdgeInsets.only(left: 9),
                          child: Text(
                            convertToK(_countLikes) + " likes",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 9,
                            ),
                          ),
                        ),//comment like count

                        GestureDetector(
                          onTap: (){

                          },
                          child: Container(
                            child: Text(
                              "Reply",
                              style: TextStyle(
                                  color: Colors.blueAccent
                              ),
                            ),
                          ),
                        ), //reply comment

                        StreamBuilder(
                            stream: _commentLikeCtr.stream,
                            builder: (BuildContext ctx, AsyncSnapshot snapshot){
                              return Material(
                                color: Colors.transparent,
                                child: InkResponse(
                                    onTap: (){
                                      likeComment(_commentLi[itemIndex]["comment_id"]);
                                    },
                                    child: _commentLikes.indexOf(globals.userId) >-1 ?
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
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ), //Post contents
        ],
      ),
    );
  }//comment block

  Widget commentList(){
    List _commentLi= jsonDecode(_commentBlockData[0]["comments"]);
    return ListView.builder(
        itemCount: _commentLi.length,
        itemBuilder: (BuildContext ctx, int itemIndex){
          if(itemIndex == 0){
            return Container(
              child: Column(
                children: <Widget>[
                  pullToRefreshContainer(),
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Color.fromRGBO(32, 32, 32, 1)
                            )
                        )
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        /*Post DP
                                    * */
                        Container(
                          margin: EdgeInsets.only(right: 16),
                          width: 32, height: 32,
                          alignment: Alignment.center,
                          child: _commentBlockData[0]["dp"].toString().length == 1 ?
                          CircleAvatar(
                            radius: 24,
                            child: Text(
                                _commentBlockData[0]["dp"]
                            ),
                          ):CircleAvatar(
                            radius: 24,
                            backgroundImage: FileImage(
                                File(_wallDir.path + "/post_media/" + _commentBlockData[0]["dp"])
                            ),
                          ),
                        ),//Post dp

                        Expanded(
                          child: Container(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  child: Text(
                                    _commentBlockData[0]["username"].toString().length>0 ?
                                    _commentBlockData[0]["username"]:
                                    _commentBlockData[0]["fullname"],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey
                                    ),
                                  ),
                                ),//username

                                Container(
                                  child: RichText(
                                    text: TextSpan(
                                      children: parseTextForLinks(_commentBlockData[0]["post_text"]),
                                    ),
                                  ),
                                ),//post text,

                                Container(
                                  margin: EdgeInsets.only(top: 12, bottom: 12),
                                  child: Text(
                                    _commentBlockData[0]["time_str"],
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 10,
                                        color: Colors.grey
                                    ),
                                  ),
                                ),//post time
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),//The Post data

                  /*First Comment
                  * */
                  commentBlock(_commentLi, itemIndex)
                  //first comment
                ],
              ),
            );
          }
          else{
            return commentBlock(_commentLi, itemIndex);
          }
        }
    );// builds the page blocks
  }//comment list

  ///The actual route's page body drawn
  Widget pageBody(){
    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 10, 10, 1),
      appBar: AppBar(
        title: Text(
            "Comments",
          style: TextStyle(
            color: Colors.grey
          ),
        ),
        backgroundColor: Color.fromRGBO(36, 36, 36, 1),
      ),
      body: FocusScope(
        child: Container(
          padding: EdgeInsets.only(left:12, right:12, top:24),
          child: StreamBuilder(
            stream: _pageStreamCtr.stream,
            builder: (BuildContext ctx, snapshot){
              if(snapshot.hasData && _commentBlockData!=null){
                return kjPullToRefresh(
                  child: commentList()
                );
              }
              else{
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(120, 120, 120, 1)),
                  ),
                );
              }
            },
          )
        ),
        onFocusChange: (bool _focusState){

        },
      ),
    );
  }//page body method

  /*Route build method
  * */
  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    return WillPopScope(
        child: MaterialApp(
          home: pageBody(),
        ),
        onWillPop: ()async{
          if(_pageDlg) _pageDlg=false;
          else Navigator.of(_pageContext).pop();
          return false;
        }
    );
  }//Route build method

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

  double pullRefreshHeight=0;
  double pullRefreshLoadHeight=80;
  StreamController pullRefreshCtr= StreamController.broadcast();
  ScrollController _globalListCtr= ScrollController();
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
                  //fetchPosts(caller: "init");
                }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(_globalListCtr.position.atEdge && !_delta.direction.isNegative){
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
}