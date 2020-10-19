import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camia/signup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import './globals.dart' as globals;
import './dbs.dart';
import './confirm_email.dart';
import 'launch_page.dart';

class Signin extends StatefulWidget{
  _Signin createState(){
    return _Signin();
  }
}

class _Signin extends State<Signin>{
  @override
  initState(){
    basicInit();
    super.initState();
  }//route's init method

  Directory _appDir;
  basicInit()async{
    //create magazine directory and start populating it
    if(_appDir == null){
      _appDir= await getApplicationDocumentsDirectory();
      Directory _magDir= Directory(_appDir.path + "/magazine");
      _magDir.create().then((value){
        Directory _coverPages= Directory(_appDir.path + "/magazine/cover_pages");
        _coverPages.create();
        Directory _innerPages= Directory(_appDir.path + "/magazine/inner_pages");
        _innerPages.create();
        fetchMagazines();
      });
    }
  }//basic init

  fetchMagazines()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl2 + "?process_as=fetch_magazines"
      );
      if(_resp.statusCode == 200){
        Database _con= await dbTables.citiMag();
        List<String> _existing= List<String>();
        List _res= await _con.rawQuery("select * from magazines");
        int _existCount= _res.length;
        for(int _k=0; _k<_existCount; _k++){
          Map _targMap= _res[_k];
          _existing.add(_targMap["mag_id"]);
        }

        List _respObj= jsonDecode(_resp.body);
        int _respCount= _respObj.length;
        String _magBooked="yes";
        String _coverStatus="complete";
        String _pageDL="pending";
        for(int _k=0; _k<_respCount; _k++){
          Map _respMap= _respObj[_k];
          String _targMID= _respMap["id"];
          if(_existing.indexOf(_targMID)<0){
            File _locMagCoverFile= File(_appDir.path + "/magazine/cover_pages/$_targMID.jpg");
            String _locCover=_respMap["cover_page"];
            String _locPageCount=_respMap["pages"];
            http.get(_locCover).then((_coverResp) {
              if(_coverResp.statusCode == 200){
                _locMagCoverFile.writeAsBytes(_coverResp.bodyBytes).then((value){
                  _con.execute("insert into magazines (title, about, period, bookmarked, mag_id, pages, status, page_path, ar, pages_dl, time_str) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [
                    _respMap["title"],
                    _respMap["about"],
                    _respMap["period"],
                    _magBooked,
                    _targMID,
                    _locPageCount,
                    _coverStatus,
                    _locCover,
                    _respMap["ar"],
                    _pageDL,
                    _respMap["time_str"]
                  ]).then((value) {
                    downloadInnerPages(_locCover, _locPageCount);
                  });
                });
              }
            });
          }
        }
      }
    }
    catch(ex){

    }
  }//fetch magazines

  downloadInnerPages(String _pagePath, String _pageCount)async{
    int _locPageCount=int.tryParse(_pageCount);
    List<String> _brkPath= _pagePath.split("/");
    String _folderID= _brkPath[_brkPath.length - 2];
    String _folderPath= _pagePath.replaceAll("/page1.jpg", "");
    for(int _k=0; _k<_locPageCount; _k++){
      String _locPage= "page" + (_k+1).toString() + ".jpg";
      File _locPageFile= File(_appDir.path + "/magazine/inner_pages/" + _folderID  + "-$_locPage");
      if(!await _locPageFile.exists()){
        try{
          http.get("$_folderPath/$_locPage").then((_innerPResp) {
            if(_innerPResp.statusCode == 200){
              _locPageFile.writeAsBytes(_innerPResp.bodyBytes);
            }
          });
        }
        catch(ex){

        }
      }
    }
  }//download the magazines inner pages here

  TextEditingController usernameCtr= TextEditingController();
  TextEditingController passnameCtr= TextEditingController();
  FocusNode passnameNode= FocusNode();

  DBTables dbTables= new DBTables();
  Size _screenSize;
  Widget pageBody(){
  return Stack(
    children: <Widget>[
      Container(
        width: _screenSize.width,
        height: _screenSize.height,
        child: ListView(
          physics: BouncingScrollPhysics(),
          children: [
            Container(
              height:_screenSize.height * .4,
              child: Stack(
                fit: StackFit.expand,
                overflow: Overflow.visible,
                children: [
                  Positioned(
                    bottom: -100,
                    right: -30,
                    child: Container(
                      width: _screenSize.width * 2,
                      height: (_screenSize.width * 2)/1.148,
                      decoration: BoxDecoration(
                          image: DecorationImage(
                              image: AssetImage("./images/galaxy_plain.png"),
                              fit: BoxFit.fitWidth
                          )
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 80),
                    padding: EdgeInsets.only(left: 45),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          child: Text(
                            "Welcome",
                            style: TextStyle(
                                fontFamily: "ubuntu",
                                fontSize: 45,
                                color: Color.fromRGBO(200, 180, 150, 1)
                            ),
                          ),
                        ),
                        Container(
                          width: _screenSize.width - 90,
                          child: Text(
                            "to a whole new world of endless possibilities",
                            style: TextStyle(
                                color: Color.fromRGBO(200, 180, 150, 1),
                                fontSize: 20,
                                fontFamily: "ubuntu"
                            ),
                          ),
                        ),
                        Container(
                          width: _screenSize.width - 90,
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            "Sign In, Now",
                            style: TextStyle(
                                fontFamily: "pacifico",
                                fontSize: 24,
                                color: Colors.orangeAccent
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 28, right: 28),
              margin: EdgeInsets.only(top: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      "Username",
                      style: TextStyle(
                          color: Color.fromRGBO(64, 64, 64, 1),
                          fontFamily: "pacifico",
                          fontSize: 16
                      ),
                    ),
                  ),//username label
                  Container(
                    margin: EdgeInsets.only(top: 3),
                    padding: EdgeInsets.only(left: 9, right: 9),
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(21, 110, 209, 1),
                        borderRadius: BorderRadius.circular(3)
                    ),
                    child: TextField(
                      controller: usernameCtr,
                      autofocus: true,
                      decoration: InputDecoration(
                          hintText: "Email or phone number",
                          hintStyle: TextStyle(
                              color: Color.fromRGBO(200, 200, 245, 1)
                          ),
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none
                      ),
                      style: TextStyle(
                          color: Colors.white
                      ),
                      onEditingComplete: (){
                        FocusScope.of(context).requestFocus(passnameNode);
                      },
                      textInputAction: TextInputAction.next,
                    ),
                  )
                ],
              ),
            ),//username
            Container(
              padding: EdgeInsets.only(left: 28, right: 28),
              margin: EdgeInsets.only(top: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(

                    child: Text(
                      "Password",
                      style: TextStyle(
                          color: Color.fromRGBO(32, 32, 32, 1),
                          fontFamily: "sail",
                          fontSize: 18
                      ),
                    ),
                  ),//label
                  Container(
                    margin: EdgeInsets.only(top: 3),
                    padding: EdgeInsets.only(left: 9, right: 9),
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(21, 110, 209, 1),
                        borderRadius: BorderRadius.circular(3)
                    ),
                    child: TextField(
                      controller: passnameCtr,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Password",
                        hintStyle: TextStyle(
                            color: Color.fromRGBO(200, 200, 245, 1)
                        ),
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                      style: TextStyle(
                          color: Colors.white
                      ),
                      focusNode: passnameNode,
                    ),
                  )
                ],
              ),
            ),//password
            Container(
              margin: EdgeInsets.only(left: 28, right: 28, top: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Color.fromRGBO(241, 93, 161, 1),
                  borderRadius: BorderRadius.circular(16)
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (){
                    tryLogin();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: 12, bottom: 12),
                    alignment: Alignment.center,
                    child: Text(
                      "Login",
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                  ),
                ),
              ),
            ),//login btn
            Container(
              margin: EdgeInsets.only(top: 24),
              padding: EdgeInsets.only(left: 36, right: 36),
              child: RichText(
                textScaleFactor: MediaQuery.of(context).textScaleFactor,
                text: TextSpan(
                    children: [
                      TextSpan(
                          text: "Don't have an account?",
                          style: TextStyle(
                              color: Color.fromRGBO(64, 64, 64, 1)
                          )
                      ),
                      TextSpan(
                          text: " Tap here to register",
                          recognizer: TapGestureRecognizer()..onTap=(){
                            Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (BuildContext _ctx){
                                      return Signup();
                                    }
                                )
                            );
                          },
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold
                          )
                      )
                    ]
                ),
              ),
            ),//dont have an account
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.only(left: 36, right: 36),
              child: RichText(
                textScaleFactor: MediaQuery.of(context).textScaleFactor,
                text: TextSpan(
                    children: [
                      TextSpan(
                          text: "Tap here ",
                          recognizer: TapGestureRecognizer()..onTap=(){
                            tryConfirmEmail();
                          },
                          style: TextStyle(
                              color: Color.fromRGBO(241, 93, 161, 1),
                              fontWeight: FontWeight.bold
                          )
                      ),
                      TextSpan(
                          text: "to confirm your email address",
                          style: TextStyle(
                              color: Color.fromRGBO(64, 64, 64, 1)
                          )
                      ),
                    ]
                ),
              ),
            ),//confirm email
          ],
        ),
      ),
      StreamBuilder(
        stream: _pageBusyCtr.stream,
        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
          if(_pageBusy){
            return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(32, 32, 32, .3)
                  ),
                  width: _screenSize.width,
                  height: _screenSize.height,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(241, 93, 161, 1)),
                          strokeWidth: 3,
                        ),
                      ),
                      Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(left: 24, right: 24),
                        child: Text(
                          _busyText,
                          style: TextStyle(
                              color: Colors.white
                          ),
                        ),
                      )
                    ],
                  ),
                )
            );
          }
          return Positioned(
            left: 0,
            bottom: -20,
            child: Container(),
          );
        },
      ),
      StreamBuilder(
        stream: _toastCtr.stream,
        builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
          if(_showToast){
            return Positioned(
              left: 0,
              top: _toastTop,
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
          }
          return Positioned(
            child: Container(),
            left: 0,
            bottom: 0,
          );
        },
      ),//toast displayer
    ],
  );
}//page body

  tryConfirmEmail()async{
    Database _con= await dbTables.loginCon();
    var _result=await _con.rawQuery("select * from user_login");
    if(_result.length == 0){
      showToast(
          persistDur: Duration(milliseconds: 7000),
          text: "Register an account first, to continue"
      );
    }
    else{
      String curStatus= _result[0]["status"];
      if(curStatus == "PENDING"){
        String curEmail=_result[0]["email"];
        Navigator.of(_pageContext).push(
            MaterialPageRoute(
                builder: (BuildContext ctx){
                  return ConfirmEmail(curEmail, _result[0]["fullname"]);
                }
            )
        );
      }
      else{
        showToast(
            persistDur: Duration(seconds: 2),
            text: "Email already verified, kindly login"
        );
      }
    }

  }//try confirm email address

  bool _loggingin=false;
  tryLogin()async{
    if(usernameCtr.text==""){
      showToast(
        text: "Username box is empty",
        persistDur: Duration(seconds: 3)
      );
      return;
    }
    else if(passnameCtr.text==""){
      showToast(
          text: "Password box is empty",
          persistDur: Duration(seconds: 3)
      );
      return;
    }

    if(_loggingin==false){
      _loggingin=true;
      showLoader(message: "Please wait ...");
      String url=globals.globBaseUrl + "?process_as=try_login";
      String _locUsername=usernameCtr.text + "";
      String _locpassname=passnameCtr.text + "";
      try{
        http.Response resp= await http.post(
            url,
            body: {
              "username": _locUsername,
              "password": _locpassname
            }
        );
        if(resp.statusCode == 200){
          _loggingin=false;
          var respObj= jsonDecode(resp.body);
          hideLoader();
          if(respObj["status"] == "success"){
            Database con= await dbTables.loginCon();
            await con.execute("delete from user_login");
            String ustatus="ACTIVATED";
            await con.execute("insert into user_login (email, password, fullname, dp, phone, status, user_id) values (?, ?, ?, ?, ?, ?, ?)", [respObj["email"], respObj["password"], respObj["fullname"], respObj["dp"], respObj["phone"], ustatus, respObj["user_id"]]);
            showToast(
                text: respObj["message"],
                persistDur: Duration(seconds: 3)
            );
            Future.delayed(
                Duration(seconds: 4),
                    (){
                  Navigator.of(_pageContext).push(
                      MaterialPageRoute(
                          builder: (BuildContext ctx){
                            return LaunchPage();
                          }
                      )
                  );
                }
            );
          }
          else{
            showToast(
                text: respObj["message"],
                persistDur: Duration(seconds: 15)
            );
          }
        }
        else{
          _loggingin=false;
          hideLoader();
          showToast(
              text: "Sorry, we could not complete this request at this time. Try again",
              persistDur: Duration(seconds: 7)
          );
        }
      }
      catch(ex){
        hideLoader();
        _loggingin=false;
        showToast(
            text: "Kindly ensure that your device is properly connected to the internet",
            persistDur: Duration(seconds: 3)
        );
      }
    }
  }//trylogin

  hideLoader(){
    _pageBusy=false;
    _pageBusyCtr.add("kjut");
  }

  bool _pageBusy=false;
  String _busyText="";
  showLoader({String message}){
    _pageBusy=true;
    _busyText=message;
    _pageBusyCtr.add("kjut");
  }

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

  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(context).size;
    _toastTop=_screenSize.height * .5;
    return WillPopScope(
        child: MaterialApp(
        home: Scaffold(
          backgroundColor: Color.fromRGBO(220, 220, 245, 1),
          body: pageBody()
        ),
      ), 
      onWillPop: (){
        return handlePagePop();
      }
    );
  }//page build

  handlePagePop() async{
    SystemChannels.platform.invokeMethod("SystemNavigator.pop");
    return true;
  }

  StreamController _pageBusyCtr= StreamController.broadcast();
  @override
  void dispose() {
    usernameCtr.dispose();
    passnameCtr.dispose();
    _pageBusyCtr.close();
    _toastCtr.close();
    super.dispose();
  }
}