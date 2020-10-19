import 'dart:async';
import 'dart:io';

import 'package:camia/dbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

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
        showToast(
          text: "Bookmarked",
          persistDur: Duration(seconds: 2)
        );
      }
      else{
        _con.execute("update magazines set bookmarked='no' where mag_id='$_magId'");
        _bookmarked=false;
        showToast(
            text: "Bookmark removed",
            persistDur: Duration(seconds: 2)
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

  Future downloadMagPage(String _pageNo)async{
    try{
      String _pageFilePath=_appDir.path + "/magazine/inner_pages/$_gpageFolder-page$_pageNo.jpg";
      String _severPagePath= _gserverPagePath.replaceAll("page1.jpg", "page$_pageNo.jpg");
      http.Response _resp= await http.get(_severPagePath);
      if(_resp.statusCode == 200){
        File _pageFile= File(_pageFilePath);
        bool _fexist= await _pageFile.exists();
        if(_fexist){
          return _pageFilePath;
        }
        else{
          _pageFile.writeAsBytesSync(_resp.bodyBytes);
          _availPages.add("page$_pageNo");
          if(_availPages.length == _magpageCount){
            Database _con= await _dbTables.citiMag();
            _con.execute("update magazines pages_dl='complete' where mag_id=?", [widget.magazineId]);
          }
          return _pageFilePath;
        }
      }
      else{
        debugPrint("kjut resp code error page $_pageNo");
        return "no network";
      }
    }
    catch(ex){
      return "no network";
    }
  }

  bool _bookmarked=false;
  double _gmagAR=1.0;
  int _magpageCount;
  String _gpageFolder;
  String _gserverPagePath="";
  List<String> _availPages=List<String>();
  fetchPages()async{
    try{
      if(_magpageCount==null) {
        Database _con = await _dbTables.citiMag();
        var _result = await _con.rawQuery("select * from magazines where mag_id=?", [widget.magazineId]);
        if (_result.length == 1) {
          _gmagAR = double.tryParse(_result[0]["ar"]);
          if (_result[0]["bookmarked"] == "yes") _bookmarked = true;
          _bookmarkNotifier.add("kjut");

          _magpageCount = int.tryParse(_result[0]["pages"]);
          _globPageChangeNotifier.add("kjut");
          _gserverPagePath = _result[0]["page_path"].toString();
          List<String> _brkServerPagePath = _gserverPagePath.split("/");
          int _pathLen = _brkServerPagePath.length;
          _gpageFolder = _brkServerPagePath[_pathLen - 2];
        }
      }
        for(int _k=0; _k<_magpageCount; _k++) {
          String _targPageStr="page${_k + 1}.jpg";
          File _tmpFile= File(_innerPages.path + "/$_gpageFolder-$_targPageStr");
          if(await _tmpFile.exists()){
            _availPages.add(_targPageStr);
            _magPages.add(Container(
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
            _magPages.add(Container(
              width: _screenSize.width,
              height: _screenSize.height/_gmagAR,
              child: FutureBuilder(
                future: downloadMagPage((_k + 1).toString()),
                builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                  if(_snapshot.hasData){
                    if(_snapshot.data == "no network"){
                      return Container(
                        padding: EdgeInsets.only(left: 16, right: 16),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 7),
                              child: Icon(
                                FlutterIcons.cloud_off_outline_mco,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                            Container(
                              child: Text(
                                "Kindly ensure that your device is properly connected to the internet",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    }
                    return Container(
                        height: _screenSize.width * (1/_gmagAR),
                        width: _screenSize.width,
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: FileImage(File(_snapshot.data)),
                                fit: BoxFit.fill,
                                alignment: Alignment.topCenter
                            )
                        )
                    );
                  }
                  return Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ));
          }
        }
      _pageAvailableNotifier.add("kjut");
    }
    catch(ex){

    }
  }//fetch pages

 // final GlobalKey _commentKey= GlobalKey();
  List<Container> _magPages= List<Container>();
  StreamController _pageAvailableNotifier= StreamController.broadcast();


  StreamController _globPageChangeNotifier= StreamController.broadcast();
  String _globCurrentPage="1";

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    _toastTop=_screenSize.height * .5;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton(
          backgroundColor: Color.fromRGBO(70, 50, 90, 1),
          onPressed: (){
            Navigator.of(_pageContext).push(
                MaterialPageRoute(
                    builder: (BuildContext _ctx){
                      return MagComment(widget.magazineId, _globCurrentPage, widget.magazineTitle);
                    }
                )
            );
          },
          child: Icon(
            FlutterIcons.comments_o_faw,
            color: Colors.white,
            size: 28,
          ),
        ),
        body: FocusScope(
          child: Container(
            child: Stack(
              children: <Widget>[
                Container(
                  height: _screenSize.height,
                  width: _screenSize.width,
                  child: ListView(
                    padding: EdgeInsets.only(top: 0),
                    children: [
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                            color: Color.fromRGBO(180, 80, 150, .8)
                        ),
                      ),//appbar padding
                      Container(
                        width: _screenSize.width,
                        padding: EdgeInsets.only(left: 32, right: 18, top: 12, bottom: 14),
                        decoration: BoxDecoration(
                            color: Color.fromRGBO(120, 80, 150, 1),
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(14)
                            )
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                child: Text(
                                  "LW Citizen Magazine",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: "ubuntu",
                                      fontSize: 20,
                                      color: Colors.white
                                  ),
                                ),
                              ),
                            ),
                            StreamBuilder(
                              stream: _globPageChangeNotifier.stream,
                              builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                                return Container(
                                  padding: EdgeInsets.only(right: 16,),
                                  child: Text(
                                    _globCurrentPage + " / " + _magpageCount.toString(),
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontFamily: "ubuntu"
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              child: StreamBuilder(
                                stream: _bookmarkNotifier.stream,
                                builder: (BuildContext _ctx, AsyncSnapshot _bookshot){
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: (){
                                        bookUnbookMark();
                                      },
                                      child: Icon(
                                        _bookmarked ? FlutterIcons.bookmark_mco : FlutterIcons.bookmark_outline_mco,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              )
                            )
                          ],
                        ),
                      ),//appbar
                      Container(
                        padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
                        child: Text(
                          widget.magazineTitle,
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontFamily: "ubuntu",
                            fontSize: 18
                          ),
                        ),
                      ),//magazine title
                      Container(
                        padding: EdgeInsets.only(left: 12, right: 12, top: 5, bottom: 5),
                        margin: EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(70, 50, 90, 1)
                        ),
                        child: StreamBuilder(
                          stream: _pageAvailableNotifier.stream,
                          builder: (BuildContext _ctx, _snapshot){
                            if(_magPages.length>0){
                              return Container(
                                width: _screenSize.width - 24, height: (_screenSize.width - 24)/_gmagAR,
                                child: InteractiveViewer(
                                  child: LiquidSwipe(
                                    pages: _magPages,
                                    onPageChangeCallback: (int _cp){
                                      _globCurrentPage= "${_cp +1}";
                                      _globPageChangeNotifier.add("kjut");
                                    },
                                    enableLoop: false,
                                  ),
                                ),
                              );
                            }
                            else return Container(
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(),
                              height: _screenSize.height * .6,
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
                StreamBuilder(
                  stream: _toastCtr.stream,
                  builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                    if(_showToast){
                      return Positioned(
                        left: 0,
                        top: _toastTop,
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 450),
                          builder: (BuildContext _ctx, double _twval, _){
                            return Opacity(
                              opacity: _twval,
                              child: Container(
                                alignment: Alignment.center,
                                width: _screenSize.width - 48,
                                margin: EdgeInsets.only(left: 24),
                                padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(241, 93, 161, 1),
                                    borderRadius: BorderRadius.circular(16)
                                ),
                                child: Text(
                                  toastText,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return Positioned(
                      child: Container(),
                      left: 0,
                      bottom: 0,
                    );
                  },
                ),//toast displayer
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


  bool _showToast=false;
  String toastText="";
  double _toastTop=0;
  StreamController _toastCtr= StreamController.broadcast();
  showToast({String text, Duration persistDur}){
    toastText=text;
    _showToast=true;
    _toastCtr.add("kjut");
    Future.delayed(
        persistDur,
            (){
          setState(() {
            _showToast=false;
            if(!_toastCtr.isClosed){
              _toastCtr.add("kjut");
            }
          });
        }
    );
  }


  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
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