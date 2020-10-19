import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sim_country_code/flutter_sim_country_code.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import './globals.dart' as globals;
import './dbs.dart';
import './confirm_email.dart';

class Signup extends StatefulWidget{
  _Signup createState(){
    return _Signup();
  }
}

class _Signup extends State<Signup>{
  
  String _uCountry="";
  TextEditingController _firstnameCtr=new TextEditingController();
  FocusNode _lastnameNode= FocusNode();
  TextEditingController _lastnameCtr=new TextEditingController();
  FocusNode _emailNode= FocusNode();
  TextEditingController _emailCtr=new TextEditingController();
  FocusNode _phoneNode= new FocusNode();
  TextEditingController _phoneCtr=new TextEditingController();

  RegExp emExp= new RegExp(r"^[a-z_0-9.-]+\@[a-z_0-9-]+\.[a-z_0-9-]+(\.[a-z_0-9-]+)*$", multiLine: true);
  
  List<DropdownMenuItem<dynamic>> genderItem= List<DropdownMenuItem<dynamic>>();
  List<String> genderStr=["Male", "Female"];
  String selectedGender="";

  DBTables dbTables= DBTables();
  DateTime tdy= DateTime.now();
  @override
  void initState() {
    trygetUserCountry();
    super.initState();
  }
  trygetUserCountry()async{
    _uCountry= await FlutterSimCountryCode.simCountryCode;
  }

  bool _registering=false;
  trySignup() async{
    if(_firstnameCtr.text == ""){
      showToast(
        text: "Kindly provide your first name to continue",
        persistDur: Duration(seconds: 3)
      );
      return;
    }
    String _firstnameStr=_firstnameCtr.text;
    if(_lastnameCtr.text == ""){
      showToast(
          text: "Kindly provide your last name to continue",
          persistDur: Duration(seconds: 3)
      );
      return;
    }
    String _lastnameStr=_lastnameCtr.text;
    if(_emailCtr.text == ""){
      showToast(
          text: "Your email address is required to continue",
          persistDur: Duration(seconds: 3)
      );
      return;
    }
    else if(!emExp.hasMatch(_emailCtr.text)){
      showToast(
          text: "An unaccepted email was provided!",
          persistDur: Duration(seconds: 3)
      );
      return;
    }
    String _locEMStr= _emailCtr.text;
    String _locphoneStr=_phoneCtr.text;
    if(_registering==false){
      _registering=true;
      showLoader(message: "A moment please ...");
      try{
        String url= globals.globBaseUrl + "?process_as=try_register";

        http.Response resp=await http.post(
            url,
            body: {
              "country": _uCountry,
              "firstname": _firstnameStr,
              "lastname": _lastnameStr,
              "email": _locEMStr,
              "phone": _locphoneStr,
            }
        );
        if(resp.statusCode == 200){
          hideLoader();
          _registering=false;
          var respObj= jsonDecode(resp.body);
          if(respObj["status"] == "success"){
            Database con= await dbTables.loginCon();
            String retEm=respObj["email"];
            String retName=respObj["fullname"];
            String retDp=respObj["dp"];
            String retPhone=respObj["phone"];
            String pwd=respObj["password"];
            String serverUid= respObj["user_id"];
            String tmpStatus="PENDING";

            _firstnameCtr.text="";
            _lastnameCtr.text="";
            _phoneCtr.text="";
            _emailCtr.text="";
            selectedGender="Male";

            con.execute("delete from user_login");
            con.execute("insert into user_login (email, password, fullname, dp, phone, status, user_id) values (?, ?, ?, ?, ?, ?, ?)", [retEm, pwd, retName, retDp, retPhone, tmpStatus, serverUid]);
            showToast(
              text: respObj["message"],
              persistDur: Duration(seconds: 30)
            );
            Future.delayed(
              Duration(seconds: 31),
                (){
                  Navigator.of(_pageContext).push(
                      MaterialPageRoute(
                          builder: (BuildContext ctx){
                            return ConfirmEmail(retEm, retName);
                          }
                      )
                  );
                }
            );
          }
          else{
            showToast(
                text: respObj["message"],
                persistDur: Duration(seconds: 3)
            );
          }
        }
      }
      catch(ex){
        hideLoader();
        _registering=false;
        showToast(
            text: "Kindly ensure that your device is properly connected to the internet",
            persistDur: Duration(seconds: 12)
        );
      }
    }
  }


  Size _screenSize;
  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    _toastTop= _screenSize.height * .4;
    return Scaffold(
      backgroundColor: Color.fromRGBO(220, 220, 245, 1),
      body: Container(
        child: Stack(
          children: [
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
                          bottom: 0,
                          left: -30,
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
                                alignment: Alignment.center,
                                child: Text(
                                  "!!!!!!!!    !!!!!!!!",
                                  style: TextStyle(
                                      fontFamily: "sail",
                                      fontSize: 45,
                                      color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                width: _screenSize.width - 90,
                                child: Text(
                                  "Excited to have you here! Fill-up the boxes below to create your account",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontFamily: "courgette"
                                  ),
                                ),
                              ),
                              Container(
                                width: _screenSize.width - 90,
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                  "Create your account now",
                                  style: TextStyle(
                                      fontFamily: "pacifico",
                                      fontSize: 24,
                                      color: Colors.black
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          child: Text(
                            "Firstname",
                            style: TextStyle(
                                color: Color.fromRGBO(25, 107, 156, 1),
                                fontFamily: "pacifico",
                                fontSize: 16
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
                            controller: _firstnameCtr,
                            autofocus: true,
                            decoration: InputDecoration(
                                hintText: "First name",
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
                              FocusScope.of(context).requestFocus(_lastnameNode);
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                  ),//firstname
                  Container(
                    padding: EdgeInsets.only(left: 28, right: 28),
                    margin: EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          child: Text(
                            "Lastname",
                            style: TextStyle(
                                color: Color.fromRGBO(25, 107, 156, 1),
                                fontFamily: "pacifico",
                                fontSize: 16
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
                            controller: _lastnameCtr,
                            focusNode: _lastnameNode,
                            decoration: InputDecoration(
                                hintText: "Last name",
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
                              FocusScope.of(context).requestFocus(_emailNode);
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                  ),//lastname
                  Container(
                    padding: EdgeInsets.only(left: 28, right: 28),
                    margin: EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          child: Text(
                            "Email",
                            style: TextStyle(
                                color: Color.fromRGBO(25, 107, 156, 1),
                                fontFamily: "pacifico",
                                fontSize: 16
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
                            controller: _emailCtr,
                            focusNode: _emailNode,
                            decoration: InputDecoration(
                                hintText: "Email address",
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
                              FocusScope.of(context).requestFocus(_phoneNode);
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                  ),//email
                  Container(
                    padding: EdgeInsets.only(left: 28, right: 28),
                    margin: EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          child: Text(
                            "Phone No.",
                            style: TextStyle(
                                color: Color.fromRGBO(25, 107, 156, 1),
                                fontFamily: "pacifico",
                                fontSize: 16
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
                            controller: _phoneCtr,
                            focusNode: _phoneNode,
                            decoration: InputDecoration(
                                hintText: "Phone number",
                                hintStyle: TextStyle(
                                    color: Color.fromRGBO(200, 200, 245, 1)
                                ),
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none
                            ),
                            style: TextStyle(
                                color: Colors.white
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                  ),//phone
                  Container(
                    margin: EdgeInsets.only(left: 28, right: 28, top: 16, bottom: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(241, 93, 161, 1),
                        borderRadius: BorderRadius.circular(16)
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (){
                          trySignup();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(top: 12, bottom: 12),
                          alignment: Alignment.center,
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                                color: Colors.white
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),//login btn
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
        ),
      ),
    );
  }//page build

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
    _pageBusyCtr.close();
    _firstnameCtr.dispose();
    _lastnameCtr.dispose();
    _emailCtr.dispose();
    _phoneCtr.dispose();
    super.dispose();
  }
}