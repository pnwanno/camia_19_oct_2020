import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:circular_clip_route/circular_clip_route.dart';
import 'package:url_launcher/url_launcher.dart' as urllaunch;
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import './globals.dart' as globals;
import './dbs.dart';
import 'kcache_mgr.dart';
import './my_wall/index.dart';
import './camtv/index.dart';
import './magazine/index.dart';
import './dictionary/index.dart';
import './dm/index.dart';
import './chapter_finder/index.dart';
import './conferences/index.dart';
import './outreaches/index.dart';

class LaunchPage extends StatefulWidget{
  _LaunchPage createState(){
    return _LaunchPage();
  }
}

class _LaunchPage extends State<LaunchPage>{
  bool globalDlg=false;
  DBTables dbTables= new DBTables();

  DateTime _kCacheExpireDate;
  Directory _appTempDir;
  @override
  initState(){
    _kCacheExpireDate= DateTime.now().add(Duration(days: 7));
    _kjutCacheMgr.listAvailableCache().then((value) {
      _availMedia=value;
    });
    initGlobalVars();
    if(!localNotificationIsInitialized) initLocalNotification();
    getTemporaryDirectory().then((value){
      _appTempDir=value;
      Directory _notiFolder= Directory(_appTempDir.path + "/local_notifications");
      _notiFolder.create();
    });
    super.initState();
  }
  static FlutterLocalNotificationsPlugin _flnp=FlutterLocalNotificationsPlugin();
  static bool localNotificationIsInitialized=false;
  static initLocalNotification(){
    AndroidInitializationSettings _androidSet=AndroidInitializationSettings("@drawable/noti_main");
    IOSInitializationSettings _iosSet= IOSInitializationSettings();
    _flnp.initialize(InitializationSettings(android: _androidSet, iOS: _iosSet),
    onSelectNotification: (String _payload)async{
      //route as per payload
    });
    localNotificationIsInitialized=true;
  }//initialize Local flutter notification

  static Future bgPushMsgHandler(Map _payload)async{
    Map _payData= {};
    if(_payload.containsKey("data")){
      _payData=_payload["data"];
      if(_payData.containsKey("k_show_notification")){
        if(_payData["k_show_notification"] == "yes"){
          String _onTapLoad="";
          if(_payData.containsKey("on_tap")) _onTapLoad= _payData["on_tap"];
          int _notiID= 0;
          if(_payData.containsKey("id")) _notiID=int.tryParse(_payData["id"]);
          String _notiTitle="";
          if(_payData.containsKey("title")) _notiTitle=_payData["title"];
          String _notiBody="";
          if(_payData.containsKey("message")) _notiBody=_payData["message"];
          String _notiChannelID="main_channel";
          if(_payData.containsKey("channel_id")) _notiChannelID=_payData["channel_id"];
          String _notiChannelName="BLW GALAXY";
          if(_payData.containsKey("channel_name")) _notiChannelName=_payData["channel_name"];
          String _notiChannelDesc="This is BLW GALAXY's main channel for displaying notifications";
          if(_payData.containsKey("channel_description")) _notiChannelDesc=_payData["channel_description"];
          AndroidNotificationDetails _androidSpec= AndroidNotificationDetails(
              _notiChannelID,
              _notiChannelName,
              _notiChannelDesc,
              color: Color.fromRGBO(32, 139, 211, 1)
          );
          if(_payData.containsKey("large_icon") || _payData.containsKey("big_picture")){
            getTemporaryDirectory().then((value)async {
              Directory _staticAppDir= value;
              String _largeIcon="";
              File _largeIconF;
              List<String> _brkPath=List();
              int _kita=DateTime.now().millisecondsSinceEpoch;
              if(_payData.containsKey("large_icon")){
                _largeIcon= _payData["large_icon"];
                _brkPath= _largeIcon.split(".");
                String _largeIconExt=_brkPath.last;
                http.Response _largeIconResp= await http.get(_largeIcon);
                _largeIconF= File(_staticAppDir.path + "/local_notifications/$_kita-li.$_largeIconExt");
                if(_largeIconResp.statusCode == 200){
                  _largeIconF.writeAsBytesSync(_largeIconResp.bodyBytes);
                }
              }
              File _bigPicF;
              String _bigPic="";
              if(_payData.containsKey("big_picture")) _bigPic=_payData["big_picture"];
              if(_bigPic!=""){
                _brkPath= _bigPic.split(".");
                String _bigPicExt=_brkPath.last;
                http.Response _bigPicResp= await http.get(_bigPic);
                if(_bigPicResp.statusCode == 200){
                  _bigPicF= File(_staticAppDir.path + "/local_notifications/$_kita-bp.$_bigPicExt");
                  _bigPicF.writeAsBytesSync(_bigPicResp.bodyBytes);
                }
              }

              var _styleInfo;
              if(_bigPic!=""){
                _styleInfo= BigPictureStyleInformation(
                  FilePathAndroidBitmap(_bigPicF.path),
                  summaryText: _notiBody,
                  htmlFormatContent: true
                );
              }
              AndroidNotificationDetails _androidSpec= AndroidNotificationDetails(
                  _notiChannelID,
                  _notiChannelName,
                  _notiChannelDesc,
                largeIcon: _largeIcon == "" ? null : FilePathAndroidBitmap(_largeIconF.path),
                styleInformation: _styleInfo,
                color: Color.fromRGBO(32, 139, 211, 1),

              );
              _flnp.show(
                  _notiID,
                  _notiTitle,
                  _notiBody,
                  NotificationDetails(
                      android: _androidSpec,
                      iOS: IOSNotificationDetails()
                  ),
                payload: _onTapLoad
              );
            });
          }
          else{
            _flnp.show(
                _notiID,
                _notiTitle,
                _notiBody,
                NotificationDetails(
                    android: _androidSpec,
                    iOS: IOSNotificationDetails()
                ),
              payload: _onTapLoad
            );
          }
        }
      }
    }
  }


  FirebaseMessaging _fbm= FirebaseMessaging();
  initPushNotification(){
    _fbm.configure(
      onMessage: (_payload)async{
        debugPrint("here is a message from on message $_payload");
      },
      onBackgroundMessage: bgPushMsgHandler
    );
    _fbm.getToken().then((_token) {
      if(_token!=null && _token!=""){
        try{
          http.post(
              globals.globBaseMiscAPI + "?process_as=update_push_notification_token",
              body: {
                "user_id": globals.userId,
                "token": _token
              }
          );
        }
        catch(ex){

        }
      }
    });
    _fbm.subscribeToTopic("KJ-ALERT-ALL");
  }//init push notification

  PageController _adSliderCtr;
  initPVCtr(){
    if(_adSliderCtr==null){
      _adSliderCtr=PageController();
      _adSliderCtr.addListener(() {
        if(_adSliderCtr.page.floor() == _adSliderCtr.page){
          _curPage=_adSliderCtr.page.toInt();
        }
      });
    }
  }

  bool _shouldSlide=false;
  int _curPage=0;
  List<String> _slideSpeeds=List<String>();
  int _slideLen;
  autoSlider()async{
    if(_slideLen==null){
      List<String> _brkPaths= _adDetails["ad_path"].toString().split(",");
      _slideLen= _brkPaths.length + 1;
      _slideSpeeds= _adDetails["slide_speed"].toString().split(",");
    }
    if(_adSliderCtr.hasClients && _slideLen>1){
      Duration _slideSpeed= Duration(seconds: 5);
      if(_curPage == 0){
        _slideSpeed=Duration(milliseconds: 9400);
      }
      else{
        if(_slideSpeeds.length>=_curPage){
          _slideSpeed=Duration(milliseconds: (int.tryParse(_slideSpeeds[_curPage-1]) * 1000) - 600);
        }
      }
      if(_shouldSlide){
        Future.delayed(
          _slideSpeed,
            (){
              if(_curPage==_slideLen - 1){
                _adSliderCtr.animateTo(0, duration: Duration(milliseconds: 600), curve: Curves.easeInOut);
              }
              else{
                _adSliderCtr.nextPage(duration: Duration(milliseconds: 600), curve: Curves.easeInOut);
              }
              Future.delayed(
                Duration(milliseconds: 350),
                  (){
                    autoSlider();
                  }
              );
            }
        );
      }
    }
  }//

  KjutCacheMgr _kjutCacheMgr= KjutCacheMgr();
  Map _availMedia=Map();
  downloadADMedia()async{
    if(_adDetails.containsKey("ad_path")){
      String _adPath= _adDetails["ad_path"];
      List<String> _brkADPath= _adPath.split(",");
      int _kount= _brkADPath.length;
      for(int _k=0; _k<_kount; _k++){
        _kjutCacheMgr.downloadFile(_brkADPath[_k], _kCacheExpireDate).then((value)async{
          _availMedia= await _kjutCacheMgr.listAvailableCache();
          if(!_otherContentsAvailNotifier.isClosed)_otherContentsAvailNotifier.add("kjut");
        });
      }
    }
  }//download ad media

  List<String> _acceptedImgExts=["jpg", "jpeg", "png", "gif"];
  //List<String> _acceptedVidExts=["mp4"];
  bool _showOtherContents=false;
  StreamController _otherContentsAvailNotifier= StreamController.broadcast();
  RegExp _hrefExp= RegExp(r"https?\:\/\/[a-z0-9-]+\.[a-z0-9-]+(\.[a-z0-9-])*?",caseSensitive: false);
  Map _adDetails={};
  check4ADs()async{
    try{
      if(globals.userId!=""){
        http.Response _resp= await http.post(
            globals.globBaseMiscAPI + "?process_as=check_for_launch_page_ad",
            body: {
              "user_id": globals.userId
            }
        );
        if(_resp.statusCode == 200){
          Map _respObj= jsonDecode(_resp.body);
          if(_respObj.containsKey("id")){
            _adDetails=_respObj;
            downloadADMedia();
            _showOtherContents=true;
            initPVCtr();
            Future.delayed(
                Duration(seconds: 1),
                    (){
                  autoSlider();
                }
            );
            if(!_otherContentsAvailNotifier.isClosed)_otherContentsAvailNotifier.add("kjut");
          }
        }
      }
    }
    catch(ex){

    }
  }//check for ads

   initGlobalVars()async{
    Database con= await dbTables.loginCon();
    var result= await con.rawQuery("select * from user_login limit 1");
    if(result.length<1){
      Future.delayed(
        Duration(milliseconds: 2000),
        (){
          SystemChannels.platform.invokeMethod("SystemNavigator.pop");
        }
      );
    }
    else{
      String ustatus= result[0]["status"];
      if(ustatus == "PENDING"){
        Future.delayed(
          Duration(milliseconds: 2000),
          (){
            SystemChannels.platform.invokeMethod("SystemNavigator.pop");
          }
        );
      }
      globals.email=result[0]["email"];
      globals.fullname=result[0]["fullname"];
      globals.password=result[0]["password"];
      globals.phone= result[0]["phone"];
      globals.userId=result[0]["user_id"];
      //initLocalNotification();
      initPushNotification();
      check4ADs();
    }
  }//initializes global variables

  int selectedIcon=-1;
  selectIcon(int iconIndex){
    setState(() {
      selectedIcon=iconIndex;
    });
    Future.delayed(
      Duration(milliseconds: buttonAniDur),
      (){
        setState(() {
          selectedIcon=-1;
        });
      }
    );
  }//select icon function

  final _wallKey= GlobalKey();
  final _cmtvKey= GlobalKey();
  final _citimagKey= GlobalKey();
  final _dictionaryKey=GlobalKey();
  final _dmKey=GlobalKey();
  final _chapterFKey=GlobalKey();
  final _conferenceKey=GlobalKey();
  final _outreachKey=GlobalKey();
  int buttonAniDur=300;
  Widget pageBody(){
    return Focus(
      child: Container(
        child: Stack(
          children: <Widget>[
            Container(
                width: _screenSize.width,
                height: _screenSize.height,
                child: ListView(
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(_pageContext).size.width,
                      height: (_screenSize.height < 600) ? 250 : (_screenSize.height < 900) ? 300 : 500,
                      child: StreamBuilder(
                        stream: _otherContentsAvailNotifier.stream,
                        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                          if(_showOtherContents){
                            List<Widget> _sliderChildren= List<Widget>();
                            double _adAR= double.tryParse(_adDetails["ar"]);
                            String _adPaths= _adDetails["ad_path"];
                            List<String> _brkADPaths= _adPaths.split(",");
                            int _count= _brkADPaths.length;
                            double _mediaHeight=_screenSize.width/_adAR;

                            _sliderChildren.add(
                                Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    Container(
                                      width: _screenSize.width,
                                      height: _mediaHeight,
                                      decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage("./images/camia_girl.png"),
                                            fit: (_screenSize.height<900) ? BoxFit.fitWidth : BoxFit.cover,
                                            alignment: Alignment.topLeft,
                                          ),
                                          borderRadius: BorderRadius.only(
                                              bottomLeft: Radius.circular(12),
                                              bottomRight: Radius.circular(12)
                                          ),
                                          gradient: SweepGradient(
                                              colors: [
                                                Color.fromRGBO(99, 142, 240, 1),
                                                Color.fromRGBO(97, 41, 153, 1),
                                                Color.fromRGBO(99, 142, 240, 1),
                                              ]
                                          )
                                      ),
                                    ), //the camia girl

                                    Positioned(
                                        bottom: 32,
                                        left: 12,
                                        child: Image.asset(
                                          "./images/explore.gif",
                                          height: 36,
                                        )
                                    ),//explore

                                    Positioned(
                                        left: 12,
                                        bottom: 14,
                                        child: Image.asset(
                                          "./images/the_blwcm.gif",
                                          height: 28,
                                        )
                                    )
                                  ],
                                )
                            );
                            for(int _k=0; _k<_count; _k++){
                              String _targPath= _brkADPaths[_k];
                              List<String> _brkPath= _targPath.split(".");
                              String _pathExt= _brkPath.last;
                              String _linkPath=_adDetails["link_to"];
                              if(_linkPath!=""){
                                _linkPath= _linkPath.toLowerCase().replaceFirst(RegExp("https?"), "to");
                                _linkPath= "https://$_linkPath";
                              }
                              if(_acceptedImgExts.indexOf(_pathExt)>-1){
                                _sliderChildren.add(Container(

                                  child: GestureDetector(
                                    onTap: (){
                                      if(_hrefExp.hasMatch(_linkPath)){
                                        urllaunch.canLaunch(_linkPath).then((value) {
                                          urllaunch.launch(_linkPath);
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: _screenSize.width,
                                      height: _mediaHeight,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: _availMedia.containsKey(_targPath) ? FileImage(File(_availMedia[_targPath])) : NetworkImage(_targPath),
                                          fit: BoxFit.cover
                                        ),
                                          borderRadius: BorderRadius.only(
                                              bottomLeft: Radius.circular(12),
                                              bottomRight: Radius.circular(12)
                                          )
                                      ),
                                    ),
                                  ),
                                ));
                              }
                            }
                            return Container(
                              width: _screenSize.width,
                              height: _mediaHeight,
                              child: PageView(
                                controller: _adSliderCtr,
                                physics: BouncingScrollPhysics(),
                                children: _sliderChildren,
                              ),
                            );
                          }
                          return Stack(
                            children: <Widget>[
                              Container(
                                width: MediaQuery.of(_pageContext).size.width,
                                height: (_screenSize.height < 600) ? 250 : (_screenSize.height < 900) ? 300 : 500,
                                decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage("./images/camia_girl.png"),
                                      fit: (_screenSize.height<900) ? BoxFit.fitWidth : BoxFit.cover,
                                      alignment: Alignment.topLeft,
                                    ),
                                    borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12)
                                    ),
                                    gradient: SweepGradient(
                                        colors: [
                                          Color.fromRGBO(99, 142, 240, 1),
                                          Color.fromRGBO(97, 41, 153, 1),
                                          Color.fromRGBO(99, 142, 240, 1),
                                        ]
                                    )
                                ),
                              ), //the camia girl

                              Positioned(
                                  bottom: 32,
                                  left: 12,
                                  child: Image.asset(
                                    "./images/explore.gif",
                                    height: 36,
                                  )
                              ),//explore

                              Positioned(
                                  left: 12,
                                  bottom: 14,
                                  child: Image.asset(
                                    "./images/the_blwcm.gif",
                                    height: 28,
                                  )
                              )
                            ],
                          );//top bg stack
                        },
                      )
                    ),//top section

                    Container(
                      padding: EdgeInsets.only(left:24, right: 24),
                      margin: EdgeInsets.only(top: 24),
                      height: _gridRowHeight * 2,
                      width: _screenSize.width,
                      child: GridView(
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9
                        ),
                        children: <Widget>[
                          AnimatedContainer(
                            key: _citimagKey,
                            duration: Duration(milliseconds: buttonAniDur),
                            padding: selectedIcon == 1 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color:selectedIcon == 1 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(1);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _citimagKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return CitiMag();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/citi_mag.png"),
                                          fit: BoxFit.contain
                                      )
                                  ),
                                ),
                              ),
                            ),
                          ),//citi magazine


                          AnimatedContainer(
                            key: _dictionaryKey,
                            duration: Duration(milliseconds: buttonAniDur),
                            padding: selectedIcon == 2 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: selectedIcon == 2 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(2);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _dictionaryKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return LWDictionary();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/lw_lexicon.png"),
                                          fit: BoxFit.contain
                                      )
                                  ),
                                ),
                              ),
                            ),
                          ),//loveworld dictionary


                          AnimatedContainer(
                            key:_wallKey,
                            duration: Duration(milliseconds: buttonAniDur),
                            padding: selectedIcon == 3 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color:selectedIcon == 3 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(3);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _wallKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return MyWall();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                        image: AssetImage("./images/mywall.png"),
                                        fit: BoxFit.contain
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),//mywall


                          AnimatedContainer(
                            key: _cmtvKey,
                            padding: selectedIcon == 4 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            duration: Duration(milliseconds: buttonAniDur),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: selectedIcon == 4 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(4);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _cmtvKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return CamTV();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                        image: AssetImage("./images/camtv.png"),
                                        fit: BoxFit.contain
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ), //camtv


                          AnimatedContainer(
                            duration: Duration(milliseconds: buttonAniDur),
                            key: _dmKey,
                            padding: selectedIcon == 5 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color:selectedIcon == 5 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(241, 93, 161, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(5);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _dmKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return DM();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/dm.png"),
                                          fit: BoxFit.contain
                                      )
                                  ),
                                ),
                              ),
                            ),
                          ),//dm


                          AnimatedContainer(
                            key: _chapterFKey,
                            duration: Duration(milliseconds: buttonAniDur),
                            padding: selectedIcon == 6 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: selectedIcon == 6 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(6);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _chapterFKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return ChapterFinder();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/chapter_finder.png"),
                                          fit: BoxFit.contain
                                      )
                                  ),
                                ),
                              ),
                            ),
                          ),//chapter finder
                        ],
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(top: 9),
                      padding: EdgeInsets.only(left:24, right: 24),
                      width: _screenSize.width,
                      height: _gridRowHeight2,
                      child: GridView(
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9
                        ),
                        children: <Widget>[
                          AnimatedContainer(
                            key:_conferenceKey,
                            duration: Duration(milliseconds: buttonAniDur),
                            padding: selectedIcon == 7 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color:selectedIcon == 7 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(7);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _conferenceKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return Conferences();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/conferences.png"),
                                          fit: BoxFit.contain
                                      )
                                  ),
                                ),
                              ),
                            ),
                          ),//conferences

                          AnimatedContainer(
                            key: _outreachKey,
                            duration: Duration(milliseconds: buttonAniDur),
                            padding: selectedIcon == 8 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color:selectedIcon == 8 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: (){
                                  selectIcon(8);
                                  Future.delayed(
                                      Duration(milliseconds: (buttonAniDur * 2) + 50),
                                          (){
                                        Navigator.of(_pageContext).push(
                                            CircularClipRoute(
                                                expandFrom: _outreachKey.currentContext,
                                                builder: (BuildContext ctx){
                                                  return Outreaches();
                                                }
                                            )
                                        );
                                      }
                                  );
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/outreaches.png"),
                                          fit: BoxFit.contain
                                      )
                                  ),
                                ),
                              ),
                            ),
                          ),//outreaches
                        ],
                      ),
                    )
                  ],
                )
            )
          ],
        ),
      ),
      onFocusChange: (bool _isFocused){
        if(_isFocused){
          _shouldSlide=true;
          check4ADs();
        }
        else{
          _shouldSlide=false;
        }
      },
      autofocus: true,
    );//page stack
  }//page body

  bool _continueAnimation=false;
  int _animPos=0;
  animateSelection(){
    _animPos++;
    selectIcon(_animPos);
    if(_animPos < 8){
      Future.delayed(
        Duration(milliseconds: 500),
          (){
            animateSelection();
          }
      );
    }
    else if(_continueAnimation){
      Future.delayed(
        Duration(seconds: 60),
          (){
            _animPos=0;
            animateSelection();
          }
      );
    }
  }

  BuildContext _pageContext;
  Size _screenSize;
  double _gridRowHeight=0;
  double _gridRowHeight2=0;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    _gridRowHeight= (_screenSize.width - 48)/3;
    _gridRowHeight2= (_screenSize.width - 48)/2;
    return WillPopScope(
      child: MaterialApp(
        theme: ThemeData(
          primarySwatch: Colors.blue
        ),
        home: Scaffold(
          body: pageBody(),
        ),
      ),
      onWillPop: ()async{
        if(globalDlg){
          setState(() {
            globalDlg=false;
          });
        }
        else SystemChannels.platform.invokeMethod("SystemNavigator.pop");
        return false;
      }
    );
  }//page build

  @override
  void dispose() {
    _otherContentsAvailNotifier.close();
    _adSliderCtr.dispose();
    super.dispose();
  }

}