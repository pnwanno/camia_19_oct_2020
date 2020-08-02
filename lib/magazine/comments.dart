import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;

import '../globals.dart' as globals;
class MagComment extends StatefulWidget{
  _MagComment createState(){
    return _MagComment();
  }
  final String magPage;
  final String magId;
  final String magTitle;
  MagComment(this.magId, this.magPage, this.magTitle);
}

class _MagComment extends State<MagComment>{
  globals.KjToast _kjToast;

  @override
  initState(){
    super.initState();
    fetchMagBody();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _commentLiCtr.add("kjut");
    });
  }//route's init state

  List _commentLi= List();
  var _magStamp;
  StreamController _commentLiCtr= StreamController.broadcast();
  Future<Widget> fetchMagStamp()async{
    if(_magStamp == null){
      try{
        http.Response _resp= await http.post(
            globals.globBaseUrl2 + "?process_as=fetch_magazine_stamp",
            body: {
              "user_id": globals.userId,
              "mag_id": widget.magId,
              "page_no": widget.magPage
            }
        );
        if(_resp.statusCode == 200){
          _magStamp=_resp.body;
        }
        else return stampShadow();
      }
      catch(ex){
        _kjToast.showToast(
            text: "Can't comment in offline mode",
            duration: Duration(seconds: 7)
        );
        return stampShadow();
      }
    }

    var _respObj= jsonDecode(_magStamp);
    String _comments= _respObj["comments"];
    return Container(
      padding: EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
                image: DecorationImage(
                    image: NetworkImage(_respObj["dp"]),
                    fit: BoxFit.fitWidth
                ),
                borderRadius: BorderRadius.circular(20)
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(bottom: 3, top: 3),
                    child: Text(
                        "Page ${widget.magPage} of " + _respObj["title"]
                    ),
                  ),
                  Container(
                    child: Text(
                      (_comments == "0") ? "No comments here - be the first to comment": "$_comments comments",
                      style: TextStyle(
                          color: Colors.grey
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }//fetch the header of the list in the page

  Widget stampShadow(){
    return Container(
      padding: EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 70, height: 75,
            decoration: BoxDecoration(
                color: Color.fromRGBO(200, 200, 200, 1)
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 40,
                    margin: EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(200, 200, 200, 1),
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                  Container(
                    height: 20,
                    margin: EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(120, 120, 120, 1),
                        borderRadius: BorderRadius.circular(12)
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }//stamp shadow

  String _replyToId="";
 // String _replyToName="";
  postComment()async{
    try{
      if(_commentCtr.text!=""){
        String _commentTxt= _commentCtr.text;
        _commentCtr.text="";
        http.Response _resp= await http.post(
          globals.globBaseUrl2 + "?process_as=post_magazine_comment",
          body: {
            "user_id": globals.userId,
            "reply_to": _replyToId,
            "comment" : _commentTxt,
            "mag_id": widget.magId,
            "page_no": widget.magPage
          }
        );
        if(_resp.statusCode == 200){
          _replyToId="";
          //_replyToName="";
          if(_resp.body == "success"){
            fetchMagBody();
          }
        }
      }
    }
    catch(ex){
      _kjToast.showToast(
        text: "Kindly connect to the internet to comment",
        duration: Duration(seconds: 3)
      );
    }
  }

  String _commentStart="0";
  Future fetchMagBody({bool noRefresh})async{
    try{
      http.Response _resp= await http.post(
        globals.globBaseUrl2 + "?process_as=fetch_magazine_comments",
        body: {
          "mag_id": widget.magId,
          "page_no" : widget.magPage,
          "start" : _commentStart
        }
      );
      if(_resp.statusCode == 200){
        if(noRefresh==true){
          _commentLi.addAll(jsonDecode(_resp.body));
        }
        else{
          _commentLi= jsonDecode(_resp.body);
        }
        _commentLiCtr.add("kjut");
      }
    }
    catch(ex){

    }
  }//fetch mag body

  TextEditingController _commentCtr= TextEditingController();
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Container(
            width: double.infinity,
            child: Text(
              "Comments on page " + widget.magPage + " - " + widget.magTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        body: FocusScope(
          autofocus: true,
          child: Container(
            child: Stack(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(left: 12, right: 12),
                  child: StreamBuilder(
                    stream: _commentLiCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                      if(_snapshot.hasData){
                        return kjPullToRefresh(
                            child: ListView.builder(
                              controller: _globalListCtr,
                                itemCount: _commentLi.length + 1,
                                itemBuilder: (BuildContext _ctx, int _itemIndex){
                                  if(_itemIndex == 0){
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          pullToRefreshContainer(),
                                          FutureBuilder(
                                            future:fetchMagStamp(),
                                            builder: (BuildContext _ctx, AsyncSnapshot _fsnapshot){
                                              if(_fsnapshot.hasData){
                                                return _fsnapshot.data;
                                              }
                                              else{
                                                return stampShadow();
                                              }
                                            },
                                          )
                                        ],
                                      ),
                                    );
                                  }
                                  else{
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Container(
                                            margin: EdgeInsets.only(bottom: 9),
                                            child: RichText(
                                              text: TextSpan(
                                                children: <TextSpan>[
                                                  TextSpan(
                                                      text: _commentLi[_itemIndex - 1]["user"] + ": ",
                                                      style: TextStyle(
                                                          color: Colors.grey,
                                                          fontFamily: "ubuntu",
                                                        fontStyle: FontStyle.italic
                                                      ),
                                                  ),
                                                  TextSpan(
                                                    text:_commentLi[_itemIndex - 1]["comment"],
                                                    style: TextStyle(
                                                      color: Color.fromRGBO(32, 32, 32, 1)
                                                    )
                                                  )
                                                ],
                                              )
                                            ),
                                          ),//username and comment
                                          Container(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Container(
                                                  margin:EdgeInsets.only(left: 16, right: 24),
                                                  child: Text(
                                                      _commentLi[_itemIndex - 1]["time"],
                                                    style: TextStyle(
                                                      color: Color.fromRGBO(120, 120, 120, 1),
                                                      fontWeight: FontWeight.bold
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkResponse(
                                                      onTap: (){

                                                      },
                                                      child: Text(
                                                        "Reply",
                                                        style: TextStyle(
                                                          color: Colors.blue
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ), //comment time and reply gesture detector
                                          (_commentLi[_itemIndex - 1]["replies"] == "0") ? Container()
                                              : Container(
                                            child: Text(
                                                "View " + _commentLi[_itemIndex - 1]["replies"].toString() + " replies"
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  }
                                }
                            )
                        );
                      }
                      else{
                        return Container(
                          alignment: Alignment.center,
                          width: _screenSize.width,
                          height: _screenSize.height,
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ),
                _kjToast
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){

          },
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          height: 200,
          child: Stack(
            fit: StackFit.loose,
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                width: _screenSize.width, height: 70,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(240, 240, 240, 1),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        child: TextField(
                          controller: _commentCtr,
                          maxLines: 1,
                          decoration: InputDecoration(
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Comment as " + globals.fullname,
                            hintStyle: TextStyle(
                              color: Colors.grey
                            )
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(18)
                      ),
                      margin: EdgeInsets.only(left: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            postComment();
                          },
                          child: Icon(
                            FlutterIcons.ios_send_ion,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      onWillPop: ()async{
        Navigator.pop(_pageContext);
        return false;
      },
    );
  }//route's build method

  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    pullRefreshCtr.close();
    _globalListCtr.dispose();
    _commentLiCtr.close();
    _commentCtr.dispose();
  }//route's dispose method

  ///This is the container placed as the first child of the listview
  ///to show a pull-to-refresh cue
  Widget pullToRefreshContainer(){
    return StreamBuilder(
      stream: pullRefreshCtr.stream,
      builder: (BuildContext ctx, AsyncSnapshot snapshot){
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: pullRefreshHeight,
          color: Color.fromRGBO(200, 200, 200, 1),
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
                      fetchMagBody();
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
          }
        },
        child: child
    );
  }//kjut pull to refresh
}