import 'package:flutter/material.dart';

import 'package:sqflite/sqflite.dart';
import './signin.dart';
import './confirm_email.dart';
import './dbs.dart';
import './launch_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DBTables dbTables= DBTables();
  @override
  void initState() {
    breathLogo();
    checkUser();
    super.initState();
  }

  checkUser()async{
    Database con= await dbTables.loginCon();
    var result=await con.rawQuery("select * from user_login");
    if(result.length>0){
      String curStatus= result[0]["status"];
      if(curStatus == "PENDING"){
        Navigator.of(_pageContext).push(
          MaterialPageRoute(
            builder: (BuildContext ctx){
              return ConfirmEmail(result[0]["email"], result[0]["fullname"]);
            }
          )
        );
      }
      else{
        Navigator.of(_pageContext).push(
          MaterialPageRoute(
            builder: (BuildContext ctx){
              return LaunchPage();
            }
          )
        );
      }
    }
    else{
      Navigator.of(_pageContext).push(
        MaterialPageRoute(
          builder: (BuildContext ctx){
            return Signin();
          }
        )
      );
    }
  }

  double animLogoWidth=150;
  breathLogo(){
    if(animLogoWidth == 150){
      setState(() {
        animLogoWidth=200;
      });
    }
    else setState(() {
      animLogoWidth=150;
    });
    Future.delayed(
      Duration(milliseconds: 1100),
      (){
        breathLogo();
      }
    );
  }

  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext = context;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        width: animLogoWidth,
        duration: Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("./images/logo.png")
          )
        ),
      ),
    );
  }
}
