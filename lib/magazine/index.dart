import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';
import 'package:http/http.dart' as http;

import '../globals.dart' as globals;
import '../dbs.dart';

class CitiMag extends StatefulWidget{
  _CitiMag createState(){
    return _CitiMag();
  }
}

class _CitiMag extends State<CitiMag>{
  DBTables _dbTables=DBTables();
  Directory _appDir;
  Directory _magDir;
  Directory _coverPages;
  globals.KjToast _kjToast;

  @override
  void initState() {
    super.initState();
    _pageBusyCtr.add("kjut");
    initDir();
  }//route's init state

  initDir()async{
    _appDir= await getApplicationDocumentsDirectory();
    _magDir=Directory(_appDir.path + "/magazine");
    await _magDir.create();
    _coverPages= Directory(_magDir.path + "/cover_pages");
    await _coverPages.create();
    fetchLocal(refresh: true);
  }//init dir

  List _globalPageData;
  fetchLocal({bool refresh})async{
    Database _con= await _dbTables.citiMag();
    var _result= await _con.rawQuery("select * from magazines where status='complete' order by id desc");
    if(_result.length>0){
      _globalPageData=_result;
      _pageBusyOpacity=0;
      _pageBusyCtr.add("kjut");
      _pageDataAvailableNotifier.add("kjut");
    }

    if(refresh){
      updateLocal();
    }
  }//fetch local

  updateLocal()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl2 + "?process_as=fetch_magazines"
      );
      if(_resp.statusCode == 200){
        Database _con= await _dbTables.citiMag();
        var _pendingRes= await _con.rawQuery("select * from magazines where status='pending'");
        int _countPending= _pendingRes.length;
        for(int _k=0; _k<_countPending; _k++){
          String _targMID= _pendingRes[_k]["mag_id"];
          File _targF= File(_coverPages.path + "/$_targMID");
          _targF.exists().then((value) {

          });
          await _con.execute("delete from magazines where mag_id='$_targMID'");
        }

        List<String> _localIds= List<String>();
        var _result= await _con.rawQuery("select mag_id from magazines where status='complete'");
        int _locCount= _result.length;
        for(int _k=0; _k<_locCount; _k++){
          _localIds.add(_result[_k]["mag_id"]);
        }
        var _serverObj= jsonDecode(_resp.body);
        int _remoteCount=_serverObj.length;
        for(int _k=0; _k<_remoteCount; _k++){
          String _targId= _serverObj[_k]["id"];
          if(_localIds.indexOf(_targId)<0){
            if(_locCount + _k > _remoteCount){
              //delete the last item on the database
              var _locres= await _con.rawQuery("select * from magazines where bookmarked='no' order by id asc limit 1");
              if(_locres.length == 1){
                File _lastfname= File(_coverPages.path + "/" + _locres[0]['mag_id'] + ".jpg");
                _lastfname.exists().then((_fexists){
                  if(_fexists){
                    _lastfname.delete();
                  }
                });
                _con.execute("delete from magazines where id=?", [_locres[0]["id"]]);
              }
            }

            String _bookmarked="no"; String _magid=_serverObj[_k]["id"];
            String _curStatus='pending';
            _con.execute("insert into magazines (title, about, period, bookmarked, mag_id, pages, status) values (?, ?, ?, ?, ?, ?, ?)", [_serverObj[_k]["title"], _serverObj[_k]["about"], _serverObj[_k]["period"], _bookmarked, _magid,_serverObj[_k]["pages"], _curStatus]).then((value){
              File _coverPageFile= File(_coverPages.path + "/$_magid.jpg");
              _coverPageFile.exists().then((_fexist) {
                if(!_fexist){
                  http.readBytes(_serverObj[_k]["cover_page"]).then((Uint8List _fbyte){
                    _coverPageFile.writeAsBytes(_fbyte).then((value){
                      _con.execute("update magazines set status='complete' where mag_id='$_magid'").then((value){
                        fetchLocal(refresh: false);
                      });
                    });
                  });
                }
              });
            });
          }
        }
      }
    }
    catch(ex){
      _kjToast.showToast(
        text: "Offline mode",
        duration: Duration(seconds: 3)
      );
    }
  }

  double _pageBusyOpacity=1;
  double _pageBusyAnimationEndVal=0;
  double _pageBusyAmount=.5;
  String _pageBusyText="Please wait ...";
  Widget pageBody(){
    return FocusScope(
      autofocus: true,
      child: Container(
        child: Stack(
          children: <Widget>[
            Container(
              child: StreamBuilder(
                stream: _pageDataAvailableNotifier.stream,
                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                  if(_snapshot.hasData){
                    return Container(
                      padding: EdgeInsets.only(left:12, right:12, top: 32),
                      child: GridView.builder(
                        itemCount: _globalPageData.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: (_screenSize.width > 700) ? 4 : 3
                          ),
                          itemBuilder: (BuildContext __ctx, int _itemIndex){
                            return GestureDetector(
                              onTap: (){

                              },
                              child: Container(
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      width: 200, height: 205,
                                      decoration: BoxDecoration(
                                          image: DecorationImage(
                                              image: FileImage(File(_coverPages.path + "/" + _globalPageData[_itemIndex]["mag_id"] + ".jpg")),
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter
                                          )
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          }
                      ),
                    );
                  }
                  else{
                    return Container();
                  }
                },
              ),
            ),
            _kjToast,
            Positioned(
              bottom: _screenSize.height * .4, left: 0,
              child: IgnorePointer(
                ignoring: true,
                child: StreamBuilder(
                  stream: _pageBusyCtr.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                    return AnimatedOpacity(
                      opacity: _pageBusyOpacity,
                      duration: Duration(milliseconds: 300),
                      child: StreamBuilder(
                        stream: _pageBusyFloatingCtr.stream,
                        builder: (BuildContext __ctx, __snapshot){
                          return TweenAnimationBuilder(
                            onEnd: (){
                              if(_pageBusyAnimationEndVal == 0)
                                _pageBusyAnimationEndVal=-12;
                              else _pageBusyAnimationEndVal=0;
                              _pageBusyFloatingCtr.add("kjut");
                            },
                            tween: Tween<double>(
                                begin: -12, end: _pageBusyAnimationEndVal
                            ),
                            duration: Duration(seconds: 1),
                            curve: Curves.easeInOut,
                            builder: (BuildContext ___ctx, double _curVal, _){
                              return Container(
                                width: _screenSize.width, height: 111,
                                alignment: Alignment.center,
                                transform: Matrix4.translationValues(0, _curVal, 0),
                                child: Stack(
                                  children: <Widget>[
                                    Container(
                                      alignment: Alignment.center,
                                      width: 120, height: 111,
                                      child: LiquidCustomProgressIndicator(
                                        direction: Axis.vertical,
                                        shapePath: globals.logoPath(Size(120, 111)),
                                        value: _pageBusyAmount,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 46, left: 30,
                                      child: Container(
                                        width: 55, height: 42,
                                        decoration: BoxDecoration(
                                            image: DecorationImage(
                                                image: AssetImage("./images/citi_mag.png"),
                                                fit: BoxFit.contain
                                            )
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 30, left: 22,
                                      child: Text(
                                        _pageBusyText,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontFamily: "ubuntu"
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),//page busy cue
          ],
        ),
      ),
    );
  }//pagebody

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast=globals.KjToast(12, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Container(
            child: Row(
              children: <Widget>[
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                      image: DecorationImage(
                          image: AssetImage("./images/citi_mag.png"),
                          fit: BoxFit.contain
                      )
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 12),
                  child: Text(
                      "LC Magazine"
                  ),
                )
              ],
            ),
          ),
        ),

        body: pageBody(),
      ),
      onWillPop: () async{
        Navigator.pop(_pageContext);
        return false;
      },
    );
  }//route's build method

  StreamController _toastCtr= StreamController.broadcast();
  StreamController _pageBusyCtr= StreamController.broadcast();
  StreamController _pageDataAvailableNotifier= StreamController.broadcast();
  StreamController _pageBusyFloatingCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    _pageBusyCtr.close();
    _pageBusyFloatingCtr.close();
    _pageDataAvailableNotifier.close();
  }//dispose
}