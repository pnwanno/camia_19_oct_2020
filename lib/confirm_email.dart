import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;

import './dbs.dart';
import './globals.dart' as globals;
import './launch_page.dart';
import './signup.dart';

class ConfirmEmail extends StatefulWidget{
  _ConfirmEmail createState(){
    return _ConfirmEmail();
  }
  final String emailStr; final String fullnameStr;
  ConfirmEmail(this.emailStr, this.fullnameStr);
}

class _ConfirmEmail extends State<ConfirmEmail>{

  DBTables dbTables=DBTables();

  TextEditingController _activateCodeCtr= TextEditingController();
  TextEditingController _newPasswordCtr=TextEditingController();
  FocusNode _newpassnode= FocusNode();

  bool _confirming=false;
  tryConfirm()async{
    if(_activateCodeCtr.text==""){
      showToast(
        text: "Activation code is required!",
        persistDur: Duration(seconds: 3)
      );
      return;
    }
    else if(_newPasswordCtr.text==""){
      showToast(
          text: "Choose a new password for your account",
          persistDur: Duration(seconds: 3)
      );
      return;
    }
    if(_confirming == false){
      _confirming=true;
      showLoader(message: "A moment please ...");
      try{
        Database con= await dbTables.loginCon();
        var result= await con.rawQuery("select * from user_login limit 1");
        if(result.length == 1){
          String uemail= result[0]["email"];
          String password= result[0]["password"];
          String status= result[0]["status"];
          if(status == "PENDING"){
            String url=globals.globBaseUrl + "?process_as=activate_account";
            http.Response resp= await http.post(
                url,
                body: {
                  "email": uemail,
                  "password": password,
                  "newpassword": _newPasswordCtr.text,
                  "code": _activateCodeCtr.text
                }
            );
            if(resp.statusCode == 200){
              _confirming=false;
              hideLoader();
              var respObj= jsonDecode(resp.body);
              if(respObj["status"] == "success"){
                await con.execute("update user_login set password=?, status=?", [_newPasswordCtr.text, 'ACTIVATED']);
                showToast(
                    text: respObj["message"],
                    persistDur: Duration(seconds: 7)
                );
                _newPasswordCtr.text="";
                _activateCodeCtr.text="";
                Future.delayed(
                    Duration(seconds: 8),
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
                    persistDur: Duration(seconds: 12)
                );
              }
            }
            else{
              hideLoader();
              showToast(
                  text: "Sorry, we can not handle this request at this time, try again later",
                  persistDur: Duration(seconds: 12)
              );
            }
          }
        }
      }
      catch(ex){
        _confirming=false;
        hideLoader();
        showToast(
            text: "Kindly ensure that your device is properly connected to the internet",
            persistDur: Duration(seconds: 12)
        );
      }
    }
  }

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(context).size;
    _toastTop=_screenSize.height * .5;
    return WillPopScope(
        child: MaterialApp(
          home: Scaffold(
              backgroundColor: Color.fromRGBO(220, 220, 245, 1),
              body: Stack(
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
                        margin: EdgeInsets.only(top: 150),
                        padding: EdgeInsets.only(left: 45),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              child: Text(
                                "Hi " + widget.fullnameStr,
                                style: TextStyle(
                                    fontFamily: "ubuntu",
                                    fontSize: 20,
                                    color: Color.fromRGBO(100, 180, 150, 1)
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              width: _screenSize.width - 90,
                              child: Text(
                                "Kindly find the activation code sent to " + widget.emailStr,
                                style: TextStyle(
                                    color: Color.fromRGBO(200, 180, 150, 1),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  fontFamily: "ubuntu"
                                ),
                              ),
                            ),
                            Container(
                              width: _screenSize.width - 90,
                              alignment: Alignment.bottomCenter,
                              child: Text(
                                "Complete your registration",
                                style: TextStyle(
                                    fontFamily: "pacifico",
                                    fontSize: 24,
                                    color: Colors.pinkAccent
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
                          "Activation Code",
                          style: TextStyle(
                              color: Color.fromRGBO(64, 64, 64, 1),
                              fontFamily: "pacifico",
                              fontSize: 16
                          ),
                        ),
                      ),//activation code
                      Container(
                        margin: EdgeInsets.only(top: 3),
                        padding: EdgeInsets.only(left: 9, right: 9),
                        decoration: BoxDecoration(
                            color: Color.fromRGBO(21, 110, 209, 1),
                            borderRadius: BorderRadius.circular(3)
                        ),
                        child: TextField(
                          controller: _activateCodeCtr,
                          autofocus: true,
                          decoration: InputDecoration(
                              hintText: "Activation code",
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
                            FocusScope.of(context).requestFocus(_newpassnode);
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
                          "New Password",
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
                          controller: _newPasswordCtr,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: "Choose a new password",
                            hintStyle: TextStyle(
                                color: Color.fromRGBO(200, 200, 245, 1)
                            ),
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                          ),
                          style: TextStyle(
                              color: Colors.white
                          ),
                          focusNode: _newpassnode,
                        ),
                      )
                    ],
                  ),
                ),//new password
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
                        tryConfirm();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.only(top: 12, bottom: 12),
                        alignment: Alignment.center,
                        child: Text(
                          "Complete Sign Up",
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
          )
          ],
        )
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

  StreamController _pageBusyCtr= StreamController.broadcast();
  @override
  void dispose() {
    _toastCtr.close();
    super.dispose();
  }
}