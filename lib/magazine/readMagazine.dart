import 'dart:async';
import 'dart:io';

import 'package:camia/dbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';
import 'package:circular_clip_route/circular_clip_route.dart';

import '../globals.dart' as globals;
import './comments.dart';


class ReadMagazine extends StatefulWidget{
  _ReadMagazine createState(){
    return _ReadMagazine();
  }
  final String magazineId;
  final String magazineTitle;
  ReadMagazine(this.magazineId, this.magazineTitle);
}


class _ReadMagazine extends State<ReadMagazine>{
  globals.KjToast _kjToast;
  initState(){
    super.initState();
    initDir();
  }//route's init state

  StreamController _bookmarkNotifier= StreamController.broadcast();
  bookUnbookMark()async{
    Database _con= await _dbTables.citiMag();
    String _magId=widget.magazineId;
    var _result=await  _con.rawQuery("select * from magazines where mag_id='$_magId'");
    if(_result.length==1){
      if(_result[0]["bookmarked"] == "no"){
        _con.execute("update magazines set bookmarked='yes' where mag_id='$_magId'");
        _bookmarked=true;
        _kjToast.showToast(
          text: "Bookmarked",
          duration: Duration(seconds: 2)
        );
      }
      else{
        _con.execute("update magazines set bookmarked='no' where mag_id='$_magId'");
        _bookmarked=false;
        _kjToast.showToast(
            text: "Bookmark removed",
            duration: Duration(seconds: 2)
        );
      }
      _bookmarkNotifier.add("kjut");
    }
  }//book and unbookmark

  bookmarg(){
    String _magId=widget.magazineId;
    _dbTables.citiMag().then((_con){
      _con.execute("update magazines set bookmarked='yes' where mag_id='$_magId'");
    });
  }

  unbookmarg(){
    String _magId=widget.magazineId;
    _dbTables.citiMag().then((_con){
      _con.execute("update magazines set bookmarked='no' where mag_id='$_magId'");
    });
  }

  DBTables _dbTables=DBTables();
  Directory _appDir;
  Directory _magDir;
  Directory _innerPages;
  initDir()async{
    _appDir= await getApplicationDocumentsDirectory();
    _magDir= Directory(_appDir.path + "/magazine");
    _innerPages= Directory(_magDir.path + "/inner_pages");
    fetchPages();
  }//init dir

  bool _bookmarked=false;
  double _gmagAR=1.0;
  int _magpageCount;
  String _gpageFolder;
  fetchPages()async{
    try{
      if(_magpageCount==null) {
        Database _con = await _dbTables.citiMag();
        var _result = await _con.rawQuery(
            "select * from magazines where mag_id=?", [widget.magazineId]);
        if (_result.length == 1) {
          _gmagAR = double.tryParse(_result[0]["ar"]);
          if (_result[0]["bookmarked"] == "yes") _bookmarked = true;
          _bookmarkNotifier.add("kjut");

          _magpageCount = int.tryParse(_result[0]["pages"]);
          _globPageChangeNotifier.add("kjut");
          String _serverPagePath = _result[0]["page_path"].toString();
          List<String> _brkServerPagePath = _serverPagePath.split("/");
          int _pathLen = _brkServerPagePath.length;
          _gpageFolder = _brkServerPagePath[_pathLen - 2];
        }
      }
        for(int _k=0; _k<_magpageCount; _k++) {
          String _targPageStr="page${_k + 1}.jpg";
          File _tmpFile= File(_innerPages.path + "/$_gpageFolder-$_targPageStr");
          if(await _tmpFile.exists()){
            if(_k==0){
              _pageBusyOpacity=0;
              _pageBusyCtr.add("kjut");
            }
            _magPages.add(Container(
              width: _screenSize.width,
              child: Container(
                height: _screenSize.width * (1/_gmagAR),
                width: _screenSize.width,
                decoration: BoxDecoration(
                    image: DecorationImage(
                        image: FileImage(_tmpFile),
                        fit: BoxFit.fill,
                        alignment: Alignment.topCenter
                    )
                ),
              ),
            ));

          }
          else{
            break;
          }
        }
      _pageAvailableNotifier.add("kjut");
    }
    catch(ex){

    }
  }//fetch pages

  final GlobalKey _commentKey= GlobalKey();
  List<Container> _magPages= List<Container>();
  StreamController _pageAvailableNotifier= StreamController.broadcast();

  double _pageBusyOpacity=1;
  double _pageBusyAmount=.5;
  String _pageBusyText="Loading ...";
  double _pageBusyAnimationEndVal=0;

  StreamController _globPageChangeNotifier= StreamController.broadcast();
  String _globCurrentPage="1";

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.magazineTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          height: 50,
          width: _screenSize.width,
          padding: EdgeInsets.only(left:20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Material(
                key: _commentKey,
                color: Colors.transparent,
                child: InkResponse(
                  onTap: (){
                    Navigator.of(_pageContext).push(
                      CircularClipRoute(
                        expandFrom: _commentKey.currentContext,
                        builder: (BuildContext _ctx){
                          return MagComment(widget.magazineId, _globCurrentPage, widget.magazineTitle);
                        }
                      )
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(50)
                    ),
                    child: Icon(
                        FlutterIcons.comments_o_faw,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              StreamBuilder(
                stream: _globPageChangeNotifier.stream,
                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                  return Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(20, 20, 20, 1)
                    ),
                    padding: EdgeInsets.only(left: 12, right: 32, top: 7, bottom: 7),
                    child: Text(
                      _globCurrentPage + " / " + _magpageCount.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontFamily: "ubuntu"
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
        body: FocusScope(
          child: Container(
            child: Stack(
              overflow: Overflow.visible,
              children: <Widget>[
                Container(
                  height: _screenSize.height,
                  width: _screenSize.width,
                  alignment: Alignment.topCenter,
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                width: (_screenSize.height<1000) ? 64 : 0,
                                color: Colors.black
                            )
                        )
                    ),
                    alignment: Alignment.topCenter,
                    height: (_screenSize.height>1200) ? _screenSize.height - 150 : _screenSize.height,
                    child: StreamBuilder(
                      stream: _pageAvailableNotifier.stream,
                      builder: (BuildContext _ctx, _snapshot){
                        if(_magPages.length>0){
                          return Container(

                            width: _screenSize.width, height: ((1/_gmagAR) * _screenSize.width) - .35,
                            child: LiquidSwipe(
                                pages: _magPages,
                              onPageChangeCallback: (int _cp){
                                _globCurrentPage= "${_cp +1}";
                                _globPageChangeNotifier.add("kjut");
                              },
                            ),
                          );
                        }
                        else return Container();
                      },
                    ),
                  ),
                ),
                _kjToast,
                Positioned(
                  bottom: _screenSize.height * .25, left: 0,
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
                                duration: Duration(milliseconds: 500),
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
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
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
                StreamBuilder(
                  stream: globals.globalCtr.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                    if(_snapshot.hasData && _snapshot.data["sender"] == "readmagazinefetchpages") fetchPages();
                    return Container();
                  },
                ),//we will use this one to monitor the fetch pages progress in the isolate
                StreamBuilder(
                  stream: _bookmarkNotifier.stream,
                  builder: (BuildContext _ctx, _snapshot){
                    return Positioned(
                      right: 5, top: -4,
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: (){
                            bookUnbookMark();
                          },
                          child: Icon(
                            FlutterIcons.bookmark_ent,
                            color: _bookmarked ? (_screenSize.height < 1000) ? Colors.blue : Colors.deepOrange: (_screenSize.height < 1000) ? Colors.white : Colors.black,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){
          },
        ),
        ),
      onWillPop: ()async{
        if(_bookmarked==false) {
          displayAlert(
              title: Text(
                  "Not Bookmarked",
              ),
              content: Text(
                  "Wouldn't you like to save this magazine for offline reading? \n\nTap 'Yes' to save now"
              ),
              action: [
                Container(
                  child: RaisedButton(
                    padding: EdgeInsets.only(top: 5, bottom: 5, right: 16, left: 16),
                    color: Colors.orange,
                    textColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)
                    ),
                    onPressed: (){
                      bookmarg();
                      Navigator.pop(dlgCtx);
                      Navigator.pop(_pageContext);
                    },
                    child: Container(
                      child: Row(
                        children: <Widget>[
                          Icon(
                            FlutterIcons.thumbs_up_ent,
                            color: Colors.white,
                          ),
                          Container(
                            margin: EdgeInsets.only(left:5),
                            child: Text(
                              "Yes",
                              style: TextStyle(
                                  fontSize: 13
                              ),
                            ),
                          )
                        ],
                      )
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 12),
                  child: RaisedButton(
                    color: Colors.red,
                    textColor: Colors.white,
                    onPressed: (){
                      unbookmarg();
                      Navigator.pop(dlgCtx);
                      Navigator.pop(_pageContext);
                    },
                    child: Text(
                      "No, please",
                      style: TextStyle(

                      ),
                    ),
                  ),
                )
              ]
          );
          return false;
        }
        else{
          Navigator.of(_pageContext).pop();
          return false;
        }
      },
    );
  }//route's build method

  StreamController _pageBusyCtr= StreamController.broadcast();
  StreamController _pageBusyFloatingCtr= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    _pageBusyCtr.close();
    _pageBusyFloatingCtr.close();
    _pageAvailableNotifier.close();
    _globPageChangeNotifier.close();
  }//route's dispose method

  BuildContext dlgCtx;
  displayAlert({@required Widget title, @required Widget content,  List<Widget> action}){
    showDialog(
        barrierDismissible: false,
        context: _pageContext,
        builder: (BuildContext localCtx){
          dlgCtx=localCtx;
          return AlertDialog(
            title: title,
            content: content,
            actions: (action!=null && action.length>0) ? action: null,
            backgroundColor: Color.fromRGBO(20, 20, 60, 1),
            contentTextStyle: TextStyle(
                color: Colors.white,
              fontSize: 15
            ),
            titleTextStyle: TextStyle(
                fontFamily: "ubuntu",
                color: Colors.white,
              fontSize: 16
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(
                    color: Colors.transparent
                )
            ),
          );
        }
    );
  }//displayAlert
}