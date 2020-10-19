import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';

import '../globals.dart' as globals;
import './profile.dart';
import '../dbs.dart';

class ProfileFF extends StatefulWidget{
  _ProfileFF createState(){
    return _ProfileFF();
  }
  final String guserId;
  final String gusername;
  final String followerCount;
  final String followingCount;
  final String tab;
  ProfileFF(this.guserId, this.gusername, this.followerCount, this.followingCount, this.tab);
}

class _ProfileFF extends State<ProfileFF> with SingleTickerProviderStateMixin{

  TabController _tabController;
  int _activeTab=0;
  @override
  void initState() {
    super.initState();
    _followers=List();
    fetchFF("tab1");
    _following=List();
    fetchFF("tab2");
    _tabController= TabController(
      vsync: this,
      length: 2,
      initialIndex: int.tryParse(widget.tab)
    );
    _activeTab= int.tryParse(widget.tab);
    _tabController.addListener(() {
      _activeTab= _tabController.index;
      _tabChangedNotifier.add("kjut");
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _tabChangedNotifier.add("kjut");
    });
  }//route's init state

  DBTables _dbTables= DBTables();
  Future followUnfollowUser(String _userId)async{
    try{
      http.post(
          globals.globBaseUrl + "?process_as=follow_unfollow_wall_user",
          body: {
            "user_id": globals.userId,
            "req_id": _userId
          }
      ).then((_resp)async{
        if(_resp.statusCode == 200){
          Database _con= await _dbTables.wallPosts();
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "following"){
            _con.execute("update wall_posts set section='following' where user_id='$_userId' and section='unfollowing'");
          }
          else if(_respObj["status"] == "unfollowing"){
            _con.execute("update wall_posts set section='unfollowing' where user_id='$_userId' and section='following'");
          }
        }
      });
    }
    catch(ex){

    }
  }//follow and unfollow

  bool _offline=false;
  List _followers= List();
  ScrollController _followerLiCtr= ScrollController();
  List _following= List();
  ScrollController _followingLiCtr= ScrollController();
  bool _firstload=false;
  fetchFF(String caller)async{
    _firstload=true;
    try{
      http.Response _resp= await http.post(
        globals.globBaseUrl + "?process_as=get_wall_profile_ff",
        body: {
          "user_id": globals.userId,
          "req_id": widget.guserId,
          "start" :  caller == "tab1" ? _followers.length.toString() : _following.length.toString(),
          "section" : caller == "tab1" ? "followers" : "following"
        }
      );
      if(_resp.statusCode == 200){
        List _respObj= jsonDecode(_resp.body);
        if(caller == "tab1"){
          _followers.addAll(_respObj);
          _tab1ListCtr.add("kjut");
        }
        else if(caller == "tab2"){
          _following.addAll(_respObj);
          _tab2ListCtr.add("kjut");
        }
      }
    }
    catch(ex){
      _offline=true;
      if(caller == "tab1"){
        _tab1ListCtr.add("kjut");
      }
      else if(caller == "tab2"){
        _tab2ListCtr.add("kjut");
      }
    }
  }

  Map<String, bool> _mfollowingMap= Map<String, bool>();
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;

    return WillPopScope(
      child: Scaffold(
        backgroundColor: Color.fromRGBO(32, 32, 32, 1),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(24, 24, 24, 1),
          title: Text(
            widget.gusername
          ),
          bottom: TabBar(
            indicator: BoxDecoration(
                shape: BoxShape.circle,
              color: Color.fromRGBO(124, 124, 124, 1)
            ),
            controller: _tabController,
            tabs: [
              StreamBuilder(
                stream: _tabChangedNotifier.stream,
                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.only(top: 5, left: 12, right: 12, bottom: 5),
                    decoration: BoxDecoration(
                        color: _activeTab == 0 ? Color.fromRGBO(60, 60, 60, 1) : Colors.transparent,
                        borderRadius: _activeTab==0 ? BorderRadius.circular(7) : BorderRadius.circular(0)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin:EdgeInsets.only(right: 3),
                          child: Icon(
                              FlutterIcons.account_arrow_right_mco,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          child: Text(
                            globals.convertToK(int.tryParse(widget.followerCount)) + " Followers",
                            style: TextStyle(
                                color: Colors.white
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder(
                stream: _tabChangedNotifier.stream,
                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.only(top: 5, left: 12, right: 12, bottom: 5),
                    decoration: BoxDecoration(
                        color: _activeTab == 1 ? Color.fromRGBO(60, 60, 60, 1) : Colors.transparent,
                        borderRadius: _activeTab==1 ? BorderRadius.circular(7) : BorderRadius.circular(0)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          child: Icon(
                              FlutterIcons.account_arrow_left_mco
                          ),
                        ),
                        Container(
                          child: Text(
                              globals.convertToK(int.tryParse(widget.followingCount)) + " Following"
                          ),
                        )
                      ],
                    ),
                  );
                },
              )
            ],
          ),
        ),

        body: FocusScope(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Container(
                width: _screenSize.width, height: _screenSize.height,
                padding: EdgeInsets.only(top: 1),
                child: TabBarView(
                  controller: _tabController,
                    physics: BouncingScrollPhysics(),
                    children: [
                      Container(
                        child: StreamBuilder(
                          stream: _tab1ListCtr.stream,
                          builder: (BuildContext _li1ctx, AsyncSnapshot _li1shot){
                            if(_firstload){
                              return ListView.builder(
                                controller: _followerLiCtr,
                                  itemCount: _followers.length,
                                  itemBuilder: (BuildContext _ctx, int _itemindex){
                                  String _uid=_followers[_itemindex]["user_id"];
                                  String _uname= _followers[_itemindex]["username"];
                                  String _udp=_followers[_itemindex]["dp"];
                                  if(!_mfollowingMap.containsKey(_uid)){
                                    if(_followers[_itemindex]["following"] == "yes") _mfollowingMap[_uid]= true;
                                    else _mfollowingMap[_uid]=false;
                                  }
                                    return GestureDetector(
                                      onTap: (){
                                        Navigator.of(_pageContext).push(
                                            MaterialPageRoute(
                                                builder: (BuildContext _ctx){
                                                  return WallProfile(_uid, username: _uname,);
                                                }
                                            )
                                        );
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: 2),
                                        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 8),
                                        decoration: BoxDecoration(
                                            color: Color.fromRGBO(24, 24, 24, 1)
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              margin: EdgeInsets.only(right: 12),
                                              child: GestureDetector(
                                                onTap: (){
                                                  Navigator.of(_pageContext).push(
                                                      MaterialPageRoute(
                                                          builder: (BuildContext _ctx){
                                                            return WallProfile(_uid, username: _uname,);
                                                          }
                                                      )
                                                  );
                                                },
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: _udp.length == 1 ?
                                                  CircleAvatar(
                                                    radius: 20,
                                                    child: Text(
                                                        _udp.toUpperCase()
                                                    ),
                                                  ): CircleAvatar(
                                                    radius: 20,
                                                    backgroundImage: NetworkImage(_udp),
                                                  ),
                                                ),
                                              ),
                                            ),//dp
                                            Expanded(
                                              child: Container(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      margin:EdgeInsets.only(bottom: 3),
                                                      child: Text(
                                                        _uname,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            fontFamily: "ubuntu",
                                                            color: Colors.grey
                                                        ),
                                                      ),
                                                    ),//username
                                                    Container(
                                                      margin:EdgeInsets.only(bottom: 3),
                                                      child: Text(
                                                        _followers[_itemindex]["fullname"],
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            color: Colors.white
                                                        ),
                                                      ),
                                                    ),//fullname
                                                  ],
                                                ),
                                              ),
                                            ),//username and fullname
                                            Container(
                                              child: Column(
                                                children: [
                                                  Container(
                                                    margin: EdgeInsets.only(bottom: 3),
                                                    child: Text(
                                                      _followers[_itemindex]["time"],
                                                      style: TextStyle(
                                                          color: Color.fromRGBO(120, 120, 120, 1)
                                                      ),
                                                    ),
                                                  ),
                                                  (_uid == globals.userId) ? Container():
                                                  Container(
                                                    child: GestureDetector(
                                                      onTap:(){
                                                        _mfollowingMap[_uid] = !_mfollowingMap[_uid];
                                                        _followChangeNotifier.add("kjut");
                                                        followUnfollowUser(_uid);
                                                      },
                                                      child: StreamBuilder(
                                                        stream:_followChangeNotifier.stream,
                                                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                                          return Container(
                                                            padding:EdgeInsets.only(top: 5, bottom: 5, left: 16, right: 16),
                                                            decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(7),
                                                                color: _mfollowingMap[_uid] ? Color.fromRGBO(20, 20, 20, 1) : Colors.orange
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Container(
                                                                  child: Icon(
                                                                    _mfollowingMap[_uid] ? FlutterIcons.account_arrow_left_mco : FlutterIcons.account_arrow_right_mco,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                                Container(
                                                                  margin:EdgeInsets.only(left: 5),
                                                                  child: Text(
                                                                    _mfollowingMap[_uid] ? "Unfollow" : "Follow",
                                                                    style: TextStyle(
                                                                        color: Colors.white
                                                                    ),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            )//follow time and gesture button
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                              );
                            }
                            else if(_offline){
                              return Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(bottom: 3),
                                      child: Icon(
                                        FlutterIcons.cloud_off_outline_mco,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Container(
                                      child: Text(
                                        "Offline",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 15
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }
                            return Container(
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(100, 100, 100, 1)),
                              ),
                            );
                          },
                        ),
                      ),//followers
                      Container(
                        child: StreamBuilder(
                          stream: _tab2ListCtr.stream,
                          builder: (BuildContext _li1ctx, AsyncSnapshot _li1shot){
                            if(_firstload){
                              return ListView.builder(
                                  controller: _followingLiCtr,
                                  itemCount: _following.length,
                                  itemBuilder: (BuildContext _ctx, int _itemindex){
                                    String _uid=_following[_itemindex]["user_id"];
                                    String _uname= _following[_itemindex]["username"];
                                    String _udp=_following[_itemindex]["dp"];
                                    if(!_mfollowingMap.containsKey(_uid)){
                                      if(_following[_itemindex]["following"] == "yes") _mfollowingMap[_uid]= true;
                                      else _mfollowingMap[_uid]=false;
                                    }
                                    return GestureDetector(
                                      onTap: (){
                                        Navigator.of(_pageContext).push(
                                            MaterialPageRoute(
                                                builder: (BuildContext _ctx){
                                                  return WallProfile(_uid, username: _uname,);
                                                }
                                            )
                                        );
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: 2),
                                        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 8),
                                        decoration: BoxDecoration(
                                            color: Color.fromRGBO(24, 24, 24, 1)
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              margin: EdgeInsets.only(right: 12),
                                              child: GestureDetector(
                                                onTap: (){
                                                  Navigator.of(_pageContext).push(
                                                      MaterialPageRoute(
                                                          builder: (BuildContext _ctx){
                                                            return WallProfile(_uid, username: _uname,);
                                                          }
                                                      )
                                                  );
                                                },
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: _udp.length == 1 ?
                                                  CircleAvatar(
                                                    radius: 20,
                                                    child: Text(
                                                        _udp.toUpperCase()
                                                    ),
                                                  ): CircleAvatar(
                                                    radius: 20,
                                                    backgroundImage: NetworkImage(_udp),
                                                  ),
                                                ),
                                              ),
                                            ),//dp
                                            Expanded(
                                              child: Container(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      margin:EdgeInsets.only(bottom: 3),
                                                      child: Text(
                                                        _uname,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            fontFamily: "ubuntu",
                                                            color: Colors.grey
                                                        ),
                                                      ),
                                                    ),//username
                                                    Container(
                                                      margin:EdgeInsets.only(bottom: 3),
                                                      child: Text(
                                                        _following[_itemindex]["fullname"],
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            color: Colors.white
                                                        ),
                                                      ),
                                                    ),//fullname
                                                  ],
                                                ),
                                              ),
                                            ),//username and fullname
                                            Container(
                                              child: Column(
                                                children: [
                                                  Container(
                                                    margin: EdgeInsets.only(bottom: 3),
                                                    child: Text(
                                                      _following[_itemindex]["time"],
                                                      style: TextStyle(
                                                          color: Color.fromRGBO(120, 120, 120, 1)
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    child: GestureDetector(
                                                      onTap:(){
                                                        _mfollowingMap[_uid] = !_mfollowingMap[_uid];
                                                        _followChangeNotifier.add("kjut");
                                                        followUnfollowUser(_uid);
                                                      },
                                                      child: StreamBuilder(
                                                        stream:_followChangeNotifier.stream,
                                                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                                          return Container(
                                                            padding:EdgeInsets.only(top: 5, bottom: 5, left: 16, right: 16),
                                                            decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(7),
                                                                color: _mfollowingMap[_uid] ? Color.fromRGBO(20, 20, 20, 1) : Colors.orange
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Container(
                                                                  child: Icon(
                                                                    _mfollowingMap[_uid] ? FlutterIcons.account_arrow_left_mco : FlutterIcons.account_arrow_right_mco,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                                Container(
                                                                  margin:EdgeInsets.only(left: 5),
                                                                  child: Text(
                                                                    _mfollowingMap[_uid] ? "Unfollow" : "Follow",
                                                                    style: TextStyle(
                                                                        color: Colors.white
                                                                    ),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            )//follow time and gesture button
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                              );
                            }
                            else if(_offline){
                              return Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(bottom: 3),
                                      child: Icon(
                                        FlutterIcons.cloud_off_outline_mco,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Container(
                                      child: Text(
                                        "Offline",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 15
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }
                            return Container(
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(100, 100, 100, 1)),
                              ),
                            );
                          },
                        ),
                      ),//following
                    ]
                )
              )
            ],
          ),
        ),
      ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  StreamController _tab1ListCtr= StreamController.broadcast();
  StreamController _tab2ListCtr= StreamController.broadcast();
  StreamController _tabChangedNotifier= StreamController.broadcast();
  StreamController _followChangeNotifier= StreamController.broadcast();
  @override
  void dispose() {
    _tabController.dispose();
    _tab1ListCtr.close();
    _tab2ListCtr.close();
    _tabChangedNotifier.close();
    _followerLiCtr.dispose();
    _followingLiCtr.dispose();
    _followChangeNotifier.close();
    super.dispose();
  }//route's dispose method
}