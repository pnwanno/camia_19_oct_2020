import 'dart:ui';

import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:circular_clip_route/circular_clip_route.dart';
import 'package:url_launcher/url_launcher.dart' as urllaunch;

import './globals.dart' as globals;
import './dbs.dart';

import './my_wall/index.dart';
import './camtv/index.dart';
import './magazine/index.dart';
import './dictionary/index.dart';

class LaunchPage extends StatefulWidget{
  _LaunchPage createState(){
    return _LaunchPage();
  }
}

class _LaunchPage extends State<LaunchPage>{
  bool globalDlg=false;
  DBTables dbTables= new DBTables();

  @override
  initState(){
    initGlobalVars();
    super.initState();
  }

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
    }
  }

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
  int buttonAniDur=300;
  Widget pageBody(){
    return Stack(
      children: <Widget>[
        Container(
          child: Column(
            children: <Widget>[
              Container(
                width: MediaQuery.of(_pageContext).size.width,
                height: (_screenSize.height < 600) ? 250 : (_screenSize.height < 900) ? 300 : 500,
                child: Stack(
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
                ),//top bg stack
              ),

              Container(
                padding: (_screenSize.width<365) ?  EdgeInsets.only(left:12, right: 12) : EdgeInsets.only(left:24, right: 24),
                height: (_screenSize.height < 600) ? 
                  _screenSize.height - 250 :
                  (_screenSize.height < 900) ?
                  _screenSize.height - 300:
                  _screenSize.height - 500,
                child: GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: (_screenSize.width > 415) ? 4 : 3,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9
                  ),
                  children: <Widget>[
                    AnimatedContainer(
                      key: _citimagKey,
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 10 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color:selectedIcon == 10 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                          borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(10);
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
                      padding: selectedIcon == 5 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: selectedIcon == 5 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
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
                                    image: AssetImage("./images/lw_dict.png"),
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
                      padding: selectedIcon == 0 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color:selectedIcon == 0 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(0);
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
                      padding: selectedIcon == 1 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      duration: Duration(milliseconds: buttonAniDur),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: selectedIcon == 1 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1)
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
                      padding: selectedIcon == 2 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      duration: Duration(milliseconds: buttonAniDur),
                      decoration: BoxDecoration(
                        color:selectedIcon == 2 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(2);
                          },
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage("./images/campods.png"),
                                fit: BoxFit.contain
                              )
                            ),
                          ),
                        ),
                      ),
                    ),//campods


                    AnimatedContainer(
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 11 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color:selectedIcon == 11 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                          borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(11);
                            urllaunch.launch("https://blwcampusministry.com/en/donate");
                          },
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                                image: DecorationImage(
                                    image: AssetImage("./images/donate.png"),
                                    fit: BoxFit.contain
                                )
                            ),
                          ),
                        ),
                      ),
                    ),//donate


                    AnimatedContainer(
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 3 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedIcon == 3 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(3);
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


                    AnimatedContainer(
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 4 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:selectedIcon == 4 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(4);
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
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 6 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:selectedIcon == 6 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(6);
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
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 7 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedIcon == 7 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(7);
                          },
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage("./images/blogs.png"),
                                fit: BoxFit.contain
                              )
                            ),
                          ),
                        ),
                      ),
                    ),//blogs


                    AnimatedContainer(
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 8 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:selectedIcon == 8 ? Color.fromRGBO(255, 215, 15, 1) : Color.fromRGBO(49, 108, 197, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(8);
                          },
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage("./images/radi8.png"),
                                fit: BoxFit.contain
                              )
                            ),
                          ),
                        ),
                      ),
                    ),//radi8

                
                    AnimatedContainer(
                      duration: Duration(milliseconds: buttonAniDur),
                      padding: selectedIcon == 9 ? EdgeInsets.all(5) : EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:selectedIcon == 9 ? Color.fromRGBO(49, 108, 197, 1) : Color.fromRGBO(255, 215, 15, 1),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            selectIcon(9);
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
    );//page stack
  }//page body


  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
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
  
}