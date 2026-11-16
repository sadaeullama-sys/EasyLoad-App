
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await DB.i.open();
 runApp(const App());
}
const red=Color(0xFFD00018), navy=Color(0xFF101B29);
final fmt=NumberFormat('#,##0.00');
class DB {
 DB._(); static final i=DB._(); late Database db;
 Future<void> open() async {
  db=await openDatabase(p.join(await getDatabasesPath(),'easyload.db'),version:2,onCreate:(d,v) async {
   for(final sql in [
    'CREATE TABLE items(id INTEGER PRIMARY KEY,name TEXT,category TEXT,qty REAL,buy REAL,sell REAL,barcode TEXT)',
    'CREATE TABLE purchases(id INTEGER PRIMARY KEY,item_name TEXT,qty REAL,unit_cost REAL,total REAL,supplier TEXT,created TEXT)',
    'CREATE TABLE sales(id INTEGER PRIMARY KEY,item_name TEXT,qty REAL,unit_price REAL,total REAL,paid REAL,customer TEXT,created TEXT)',
    'CREATE TABLE payments(id INTEGER PRIMARY KEY,party TEXT,kind TEXT,amount REAL,note TEXT,created TEXT)',
    'CREATE TABLE expenses(id INTEGER PRIMARY KEY,category TEXT,amount REAL,note TEXT,created TEXT)',
    'CREATE TABLE customers(id INTEGER PRIMARY KEY,name TEXT,phone TEXT,address TEXT)',
    'CREATE TABLE service_transactions(id INTEGER PRIMARY KEY,service TEXT,amount REAL,commission REAL,customer TEXT,created TEXT)',
    'CREATE TABLE rso_daily(id INTEGER PRIMARY KEY,ledger_date TEXT,company TEXT,opening REAL,load2 REAL,sale REAL,rso_remaining REAL,transfer REAL,katta REAL,note TEXT)',
    'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)',
    'CREATE TABLE payment_requests(id INTEGER PRIMARY KEY AUTOINCREMENT,email TEXT,plan TEXT,amount REAL,method TEXT,payer_name TEXT,payer_phone TEXT,transaction_id TEXT,status TEXT,created TEXT)'
   ]) { await d.execute(sql); }
   await d.insert('settings',{'key':'user','value':'admin'});
   await d.insert('settings',{'key':'pin','value':'1234'});
   await d.insert('settings',{'key':'shop','value':'EasyLoad Shop Manager'});
   await d.insert('settings',{'key':'trial_started', 'value':DateTime.now().toIso8601String()});
   await d.insert('settings',{'key':'subscription_status','value':'trial'});
   await d.insert('settings',{'key':'subscription_until','value':''});
   await d.insert('settings',{'key':'jazzcash_title','value':''});
   await d.insert('settings',{'key':'jazzcash_number','value':''});
   await d.insert('settings',{'key':'easypaisa_title','value':''});
   await d.insert('settings',{'key':'easypaisa_number','value':''});
  },onUpgrade:(d,oldVersion,newVersion) async {
   if(oldVersion<2) {
    await d.execute('CREATE TABLE IF NOT EXISTS payment_requests(id INTEGER PRIMARY KEY AUTOINCREMENT,email TEXT,plan TEXT,amount REAL,method TEXT,payer_name TEXT,payer_phone TEXT,transaction_id TEXT,status TEXT,created TEXT)');
    for(final entry in <String,String>{
      'trial_started':DateTime.now().toIso8601String(),
      'subscription_status':'trial','subscription_until':'',
      'jazzcash_title':'','jazzcash_number':'','easypaisa_title':'','easypaisa_number':''
    }.entries) {
      await d.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
   }
  });
  // Defensive defaults for an existing database upgraded from older builds.
  for(final entry in <String,String>{
   'trial_started':DateTime.now().toIso8601String(),
   'subscription_status':'trial','subscription_until':'',
   'jazzcash_title':'','jazzcash_number':'','easypaisa_title':'','easypaisa_number':''
  }.entries) {
   await db.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.ignore);
  }
 }
 Future<String> setting(String key,String fallback) async {
  final r=await db.query('settings',where:'key=?',whereArgs:[key],limit:1);
  return r.isEmpty?fallback:'${r.first['value']??fallback}';
 }
 Future<void> setSetting(String key,String value) async {
  await db.insert('settings',{'key':key,'value':value},conflictAlgorithm:ConflictAlgorithm.replace);
 }
 Future<int> daysLeftInTrial() async {
  final raw=await setting('trial_started',DateTime.now().toIso8601String());
  final start=DateTime.tryParse(raw)??DateTime.now();
  final end=start.add(const Duration(days:7));
  final seconds=end.difference(DateTime.now()).inSeconds;
  return seconds<=0?0:((seconds+86399)~/86400);
 }
 Future<bool> hasActiveSubscription() async {
  final status=await setting('subscription_status','trial');
  final until=DateTime.tryParse(await setting('subscription_until',''));
  return status=='active' && until!=null && until.isAfter(DateTime.now());
 }
 Future<List<Map<String,Object?>>> all(String t)=>db.query(t,orderBy:'id DESC');
 Future<double> total(String t,String c) async {final r=await db.rawQuery('SELECT COALESCE(SUM($c),0) x FROM $t');return (r.first['x'] as num).toDouble();}
}
class App extends StatelessWidget {const App({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'EasyLoad Shop Manager',debugShowCheckedModeBanner:false,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:red),useMaterial3:true),home:const SubscriptionGate());}
class Login extends StatefulWidget {const Login({super.key});@override State<Login> createState()=>_LoginState();}
class _LoginState extends State<Login>{
 final u=TextEditingController(text:'admin'),pw=TextEditingController();String err='';
 @override Widget build(BuildContext c)=>Scaffold(body:Center(child:Card(margin:const EdgeInsets.all(24),child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
 const Icon(Icons.storefront,size:56,color:red),const Text('EasyLoad Shop Manager',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
 TextField(controller:u,decoration:const InputDecoration(labelText:'Username')),TextField(controller:pw,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
 if(err.isNotEmpty)Text(err,style:const TextStyle(color:red)),
 FilledButton(onPressed:()async{final a=(await DB.i.db.query('settings',where:'key=?',whereArgs:['user'])).first['value'];final b=(await DB.i.db.query('settings',where:'key=?',whereArgs:['pin'])).first['value'];if(u.text==a&&pw.text==b){if(c.mounted)Navigator.pushReplacement(c,MaterialPageRoute(builder:(_)=>const Home()));}else{setState(()=>err='Login incorrect');}},child:const Text('Login')),
 const Text('First login: admin / 1234',style:TextStyle(fontSize:12,color:Colors.grey))
 ])))));
 }
class Home extends StatefulWidget {const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
 int ix=0; final names=['Dashboard','Stock','Purchase','Sale','Services','E Zero / RSO','Customers','Payments','Expenses','Reports','Settings'];
 final icons=[Icons.dashboard,Icons.inventory,Icons.shopping_cart,Icons.point_of_sale,Icons.account_balance_wallet,Icons.calculate,Icons.people,Icons.receipt,Icons.money_off,Icons.analytics,Icons.settings];
 @override Widget build(BuildContext c){final pages=[const Dashboard(),const StockPage(),const PurchasePage(),const SalePage(),const ServicePage(),const RsoPage(),const CustomerPage(),const PaymentPage(),const ExpensePage(),const ReportPage(),const SettingsPage()];return Scaffold(appBar:AppBar(title:Text(names[ix]),backgroundColor:navy,foregroundColor:Colors.white),drawer:Drawer(child:ListView(children:[const DrawerHeader(decoration:BoxDecoration(color:navy),child:Align(alignment:Alignment.bottomLeft,child:Text('EasyLoad Shop Manager',style:TextStyle(color:Colors.white,fontSize:20)))),for(int i=0;i<names.length;i++)ListTile(leading:Icon(icons[i]),title:Text(names[i]),selected:ix==i,onTap:(){setState(()=>ix=i);Navigator.pop(c);})])),body:pages[ix]);}
}
class Dashboard extends StatefulWidget {const Dashboard({super.key});@override State<Dashboard> createState()=>_DashboardState();}
class _DashboardState extends State<Dashboard>{Map<String,String> vals={};@override void initState(){super.initState();load();}Future<void>load()async{vals={'Stock Items':'${(await DB.i.db.rawQuery('SELECT COUNT(*) n FROM items')).first['n']}','Sales':'Rs. ${fmt.format(await DB.i.total('sales','total'))}','Purchases':'Rs. ${fmt.format(await DB.i.total('purchases','total'))}','Payments':'Rs. ${fmt.format(await DB.i.total('payments','amount'))}','Expenses':'Rs. ${fmt.format(await DB.i.total('expenses','amount'))}'};if(mounted)setState((){});}@override Widget build(BuildContext c)=>RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(14),children:[const Text('Shop Overview',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,children:vals.entries.map((e)=>Card(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(e.key),Text(e.value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))])))).toList()),const Text('Offline SQLite storage is enabled.'),const Text('Developer: Muhammad Ilyas') ]));}
class EntryPage extends StatefulWidget {final String title,table;final List<String> fields;const EntryPage(this.title,this.table,this.fields,{super.key});@override State<EntryPage> createState()=>_EntryPageState();}
class _EntryPageState extends State<EntryPage>{final ctrls=<String,TextEditingController>{};List<Map<String,Object?>> rows=[];@override void initState(){super.initState();for(final f in widget.fields)ctrls[f]=TextEditingController();load();}Future<void>load()async{rows=await DB.i.all(widget.table);if(mounted)setState((){});}Future<void>save()async{final data=<String,Object?>{};for(final f in widget.fields){final v=ctrls[f]!.text;data[f]=double.tryParse(v)??v;}await DB.i.db.insert(widget.table,data);for(final x in ctrls.values)x.clear();await load();} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[Text(widget.title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final f in widget.fields)TextField(controller:ctrls[f],decoration:InputDecoration(labelText:f.replaceAll('_',' '))),FilledButton(onPressed:save,child:const Text('Save Record')),const Divider(),...rows.map((r)=>Card(child:ListTile(title:Text(r.entries.take(2).map((e)=>'${e.key}: ${e.value??''}').join(' • ')),subtitle:Text(r.entries.skip(2).map((e)=>'${e.key}: ${e.value??''}').join(' | '))))) ]);}
class StockPage extends StatefulWidget{const StockPage({super.key});@override State<StockPage> createState()=>_StockPageState();}
class _StockPageState extends State<StockPage>{final n=TextEditingController(),q=TextEditingController(text:'0'),b=TextEditingController(text:'0'),s=TextEditingController(text:'0'),cat=TextEditingController(),code=TextEditingController();List<Map<String,Object?>> rows=[];Future<void>load()async{rows=await DB.i.all('items');if(mounted)setState((){});}@override void initState(){super.initState();load();}Future<void>save()async{if(n.text.trim().isEmpty)return;await DB.i.db.insert('items',{'name':n.text,'category':cat.text,'qty':double.tryParse(q.text)??0,'buy':double.tryParse(b.text)??0,'sell':double.tryParse(s.text)??0,'barcode':code.text});await load();}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('Stock Management',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final x in [('Item name',n),('Category',cat),('Quantity',q),('Buy price',b),('Sell price',s),('Barcode / QR',code)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1)),FilledButton(onPressed:save,child:const Text('Add Stock Item')),const Divider(),...rows.map((r)=>ListTile(title:Text('${r['name']}'),subtitle:Text('Qty ${r['qty']} • Buy ${r['buy']} • Sell ${r['sell']} • ${r['barcode']??''}')))]);}
class PurchasePage extends StatefulWidget{const PurchasePage({super.key});@override State<PurchasePage> createState()=>_PurchasePageState();}
class _PurchasePageState extends State<PurchasePage>{final item=TextEditingController(),qty=TextEditingController(),rate=TextEditingController(),supplier=TextEditingController();Future<void>save()async{final q=double.tryParse(qty.text)??0,r=double.tryParse(rate.text)??0;if(item.text.isEmpty||q<=0)return;await DB.i.db.insert('purchases',{'item_name':item.text,'qty':q,'unit_cost':r,'total':q*r,'supplier':supplier.text,'created':DateTime.now().toIso8601String()});final a=await DB.i.db.query('items',where:'name=?',whereArgs:[item.text]);if(a.isEmpty){await DB.i.db.insert('items',{'name':item.text,'qty':q,'buy':r,'sell':0});}else{await DB.i.db.rawUpdate('UPDATE items SET qty=qty+?,buy=? WHERE id=?',[q,r,a.first['id']]);}if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Purchase saved and stock updated')));setState((){});}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('Purchase',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final x in [('Item name',item),('Quantity',qty),('Unit cost Rs',rate),('Supplier',supplier)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1)),FilledButton(onPressed:save,child:const Text('Save Purchase'))]);}
class SalePage extends StatefulWidget{const SalePage({super.key});@override State<SalePage> createState()=>_SalePageState();}
class _SalePageState extends State<SalePage>{final item=TextEditingController(),qty=TextEditingController(text:'1'),price=TextEditingController(),paid=TextEditingController(text:'0'),customer=TextEditingController();Future<void>save()async{final q=double.tryParse(qty.text)??0,r=double.tryParse(price.text)??0,pd=double.tryParse(paid.text)??0;final a=await DB.i.db.query('items',where:'name=?',whereArgs:[item.text]);if(a.isEmpty||q<=0||(a.first['qty'] as num)<q){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Item not found or stock insufficient')));return;}await DB.i.db.insert('sales',{'item_name':item.text,'qty':q,'unit_price':r,'total':q*r,'paid':pd,'customer':customer.text,'created':DateTime.now().toIso8601String()});await DB.i.db.rawUpdate('UPDATE items SET qty=qty-? WHERE id=?',[q,a.first['id']]);await DB.i.db.insert('payments',{'party':customer.text,'kind':'Sale received','amount':pd,'note':item.text,'created':DateTime.now().toIso8601String()});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sale completed')));}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('Sale',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final x in [('Item name',item),('Quantity',qty),('Unit price Rs',price),('Received Rs',paid),('Customer',customer)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1)),FilledButton(onPressed:save,child:const Text('Complete Sale'))]);}
const Map<String,String> providerLogoAssets = {
 'Jazz':'assets/provider_logos/jazz_network.png',
 'Zong':'assets/provider_logos/zong_network.png',
 'Telenor':'assets/provider_logos/telenor_network.png',
 'Ufone':'assets/provider_logos/ufone_network.png',
 'SCO':'assets/provider_logos/sco_network.png',
 'ONIC':'assets/provider_logos/onic_network.png',
 'One Load':'assets/provider_logos/one_load.png',
 'Udhaar App':'assets/provider_logos/udhaar_app.png',
 'Cash':'assets/provider_logos/cash.png',
 'EasyPaisa':'assets/provider_logos/udhaar_app.png',
 'JazzCash':'assets/provider_logos/jazz.png',
};

class ProviderLogo extends StatelessWidget {
 final String name; final double size;
 const ProviderLogo(this.name,{super.key,this.size=42});
 @override Widget build(BuildContext context) {
  final asset=providerLogoAssets[name];
  if(asset==null) return CircleAvatar(radius:size/2,child:Text(name.isEmpty?'?':name[0]));
  return Container(width:size,height:size,padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.black12)),child:Image.asset(asset,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Center(child:Text(name[0]))));
 }
}

class ProviderDropdownItem extends StatelessWidget {
 final String name;
 const ProviderDropdownItem(this.name,{super.key});
 @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[ProviderLogo(name,size:34),const SizedBox(width:10),Flexible(child:Text(name,overflow:TextOverflow.ellipsis))]);
}

class ServicePage extends StatefulWidget{const ServicePage({super.key});@override State<ServicePage> createState()=>_ServicePageState();}
class _ServicePageState extends State<ServicePage>{
 String svc='Jazz';
 final amount=TextEditingController(),commission=TextEditingController(text:'0'),customer=TextEditingController();
 final services=['Jazz','Zong','Telenor','Ufone','SCO','ONIC','One Load','Udhaar App','Cash','EasyPaisa','JazzCash'];
 Future<void>save()async{
  await DB.i.db.insert('service_transactions',{'service':svc,'amount':double.tryParse(amount.text)??0,'commission':double.tryParse(commission.text)??0,'customer':customer.text,'created':DateTime.now().toIso8601String()});
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$svc transaction saved')));
 }
 @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
  const Text('Mobile Services Ledger',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  const SizedBox(height:12),
  const Text('Select Network / Service',style:TextStyle(fontWeight:FontWeight.w600)),
  GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,childAspectRatio:1.18,crossAxisSpacing:8,mainAxisSpacing:8),itemCount:services.length,itemBuilder:(context,index){final name=services[index];final selected=svc==name;return InkWell(onTap:()=>setState(()=>svc=name),borderRadius:BorderRadius.circular(14),child:Container(decoration:BoxDecoration(color:selected?red.withOpacity(.08):Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:selected?red:Colors.black12,width:selected?2:1)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[ProviderLogo(name,size:46),const SizedBox(height:5),Text(name,textAlign:TextAlign.center,style:TextStyle(fontWeight:selected?FontWeight.bold:FontWeight.w500,color:selected?red:null,fontSize:12))])));}),
  const SizedBox(height:12),
  Card(child:ListTile(leading:ProviderLogo(svc,size:48),title:Text(svc,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Selected service for this transaction'))),
  TextField(controller:amount,decoration:const InputDecoration(labelText:'Amount Rs'),keyboardType:TextInputType.number),
  TextField(controller:commission,decoration:const InputDecoration(labelText:'Commission Rs'),keyboardType:TextInputType.number),
  TextField(controller:customer,decoration:const InputDecoration(labelText:'Customer')),
  const SizedBox(height:10),FilledButton(onPressed:save,child:Text('Save $svc Transaction'))
 ]);
}

class RsoPage extends StatefulWidget{const RsoPage({super.key});@override State<RsoPage> createState()=>_RsoPageState();}
class _RsoPageState extends State<RsoPage>{
 String company='Jazz';
 final opening=TextEditingController(text:'0'),load=TextEditingController(text:'0'),sale=TextEditingController(text:'0'),remaining=TextEditingController(text:'0'),transfer=TextEditingController(text:'0'),katta=TextEditingController(text:'0'),note=TextEditingController();
 final companies=['Jazz','Zong','Telenor','Ufone','SCO','ONIC','Udhaar App','One Load','Cash'];
 double v(TextEditingController x)=>double.tryParse(x.text)??0;
 Future<void>save()async{await DB.i.db.insert('rso_daily',{'ledger_date':DateFormat('yyyy-MM-dd').format(DateTime.now()),'company':company,'opening':v(opening),'load2':v(load),'sale':v(sale),'rso_remaining':v(remaining),'transfer':v(transfer),'katta':v(katta),'note':note.text});if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$company E Zero record saved')));}
 @override Widget build(BuildContext c){final total=v(opening)+v(load),rem=total-v(sale),ledger=v(remaining)-v(transfer)-v(katta);return ListView(padding:const EdgeInsets.all(12),children:[
  const Text('E Zero / RSO Ledger',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  DropdownButtonFormField<String>(value:company,items:companies.map((s)=>DropdownMenuItem<String>(value:s,child:ProviderDropdownItem(s))).toList(),selectedItemBuilder:(context)=>companies.map((s)=>ProviderDropdownItem(s)).toList(),onChanged:(v)=>setState(()=>company=v!),decoration:const InputDecoration(labelText:'Company / Network')),
  Card(child:ListTile(leading:ProviderLogo(company,size:48),title:Text(company,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Selected ledger'))),
  for(final x in [('Opening Balance',opening),('2 Day Load',load),('Sale',sale),('RSO Total Remaining',remaining),('Today Transfer',transfer),('RSO Katta',katta),('Note',note)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1),keyboardType:x.$1=='Note'?TextInputType.text:TextInputType.number),
  Card(child:Padding(padding:const EdgeInsets.all(12),child:Text('Total Balance = Rs. ${fmt.format(total)}\nRemaining = Rs. ${fmt.format(rem)}\nRemaining Ledger = Rs. ${fmt.format(ledger)}',style:const TextStyle(fontWeight:FontWeight.bold)))),
  FilledButton(onPressed:save,child:const Text('Save Daily Record'))
 ]);}
}
class CustomerPage extends StatelessWidget{const CustomerPage({super.key});@override Widget build(BuildContext c)=>const EntryPage('Customer Directory','customers',['name','phone','address']);}
class PaymentPage extends StatelessWidget{const PaymentPage({super.key});@override Widget build(BuildContext c)=>const EntryPage('Payments / Receipts','payments',['party','kind','amount','note','created']);}
class ExpensePage extends StatelessWidget{const ExpensePage({super.key});@override Widget build(BuildContext c)=>const EntryPage('Expenses','expenses',['category','amount','note','created']);}
class ReportPage extends StatelessWidget{const ReportPage({super.key});Future<void>pdf()async{final items=await DB.i.all('items'),sales=await DB.i.all('sales');final doc=pw.Document();doc.addPage(pw.MultiPage(build:(_)=>[pw.Header(level:0,child:pw.Text('EasyLoad Shop Manager Report')),pw.Header(level:1,child:pw.Text('Stock')),pw.TableHelper.fromTextArray(data:[['Name','Qty','Buy','Sell'],...items.map((r)=>[r['name'],r['qty'],r['buy'],r['sell']])]),pw.Header(level:1,child:pw.Text('Sales')),pw.TableHelper.fromTextArray(data:[['Item','Qty','Total','Paid'],...sales.map((r)=>[r['item_name'],r['qty'],r['total'],r['paid']])])]));await Printing.layoutPdf(onLayout:(_)=>doc.save());}Future<void>backup()async{final dir=await getExternalStorageDirectory();await File('${dir!.path}/easyload_backup.db').writeAsBytes(await File(DB.i.db.path).readAsBytes());} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Reports & Backup',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),FilledButton(onPressed:pdf,child:const Text('Create PDF Report')),FilledButton(onPressed:backup,child:const Text('Create Database Backup')),const Text('Backup is saved in the app external files folder. Restore/import workflow is not yet implemented.')]);}

class SubscriptionGate extends StatefulWidget {
 const SubscriptionGate({super.key});
 @override State<SubscriptionGate> createState()=>_SubscriptionGateState();
}
class _SubscriptionGateState extends State<SubscriptionGate> {
 bool loading=true,allowed=false; int days=0;
 @override void initState(){super.initState();check();}
 Future<void> check() async {
  final active=await DB.i.hasActiveSubscription();
  final left=await DB.i.daysLeftInTrial();
  if(mounted)setState(() { loading=false; allowed=active||left>0; days=left; });
 }
 @override Widget build(BuildContext c) {
  if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
  if(allowed)return const Login();
  return SubscriptionPage(onActivated:check,expired:true);
 }
}
class SubscriptionPage extends StatefulWidget {
 final VoidCallback? onActivated; final bool expired;
 const SubscriptionPage({super.key,this.onActivated,this.expired=false});
 @override State<SubscriptionPage> createState()=>_SubscriptionPageState();
}
class _SubscriptionPageState extends State<SubscriptionPage> {
 String plan='Monthly',method='JazzCash'; final email=TextEditingController(),payer=TextEditingController(),phone=TextEditingController(),txn=TextEditingController();
 String info=''; int days=0; bool active=false; String until='';
 @override void initState(){super.initState();load();}
 Future<void> load() async {
  days=await DB.i.daysLeftInTrial(); active=await DB.i.hasActiveSubscription();
  until=await DB.i.setting('subscription_until','');
  email.text=await DB.i.setting('account_email','');
  if(mounted)setState((){});
 }
 double get price=>plan=='Monthly'?500:5000;
 Future<void> submit() async {
  if(email.text.trim().isEmpty||!email.text.contains('@')||payer.text.trim().isEmpty||phone.text.trim().isEmpty||txn.text.trim().isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter email, payer name, phone and transaction/reference ID.')));return;
  }
  await DB.i.setSetting('account_email',email.text.trim());
  await DB.i.db.insert('payment_requests',{'email':email.text.trim(),'plan':plan,'amount':price,'method':method,'payer_name':payer.text.trim(),'payer_phone':phone.text.trim(),'transaction_id':txn.text.trim(),'status':'Pending','created':DateTime.now().toIso8601String()});
  if(mounted) {
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Payment request saved as Pending. Admin must verify the transaction before activation.')));
   txn.clear(); setState((){});
  }
 }
 Future<void> approveLatest() async {
  final pin=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Admin approval'),content:TextField(controller:pin,obscureText:true,decoration:const InputDecoration(labelText:'Admin PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Verify'))]));
  if(ok!=true)return;
  final saved=await DB.i.setting('pin','1234');
  if(pin.text!=saved){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Incorrect admin PIN')));return;}
  final requests=await DB.i.db.query('payment_requests',where:'status=?',whereArgs:['Pending'],orderBy:'id DESC',limit:1);
  if(requests.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No pending payment request found')));return;}
  final r=requests.first;
  final verified=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
   title:const Text('Verify manual payment'),
   content:Text('Email: ${r['email']}\nPayer: ${r['payer_name']}\nPhone: ${r['payer_phone']}\nMethod: ${r['method']}\nAmount: PKR ${r['amount']}\nTransaction ID: ${r['transaction_id']}\n\nApprove only after checking the payment in your JazzCash/Easypaisa account.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Payment verified — Approve'))],
  ));
  if(verified!=true)return;
  final months=r['plan']=='Yearly'?12:1;
  final now=DateTime.now(); final base=DateTime.tryParse(await DB.i.setting('subscription_until',''))??now;
  final start=base.isAfter(now)?base:now;
  final targetMonth=DateTime(start.year,start.month+months,1);
  final lastDay=DateTime(targetMonth.year,targetMonth.month+1,0).day;
  final expiry=DateTime(targetMonth.year,targetMonth.month,start.day.clamp(1,lastDay).toInt(),start.hour,start.minute);
  await DB.i.setSetting('subscription_status','active');
  await DB.i.setSetting('subscription_until',expiry.toIso8601String());
  await DB.i.db.update('payment_requests',{'status':'Approved'},where:'id=?',whereArgs:[r['id']]);
  if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Subscription activated until ${DateFormat('dd MMM yyyy').format(expiry)}')));setState((){});widget.onActivated?.call();}
 }
 @override Widget build(BuildContext c)=>Scaffold(
  appBar:AppBar(title:const Text('EasyLoad Subscription'),backgroundColor:navy,foregroundColor:Colors.white),
  body:ListView(padding:const EdgeInsets.all(16),children:[
   const Icon(Icons.workspace_premium,color:red,size:54),
   const Text('EasyLoad Shop Manager',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
   const SizedBox(height:12),
   Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
    Text(active?'Subscription Active':(days>0?'7-Day Free Trial':'Free Trial Expired'),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
    const SizedBox(height:6),
    Text(active?'Valid until: $until':(days>0?'$days day(s) remaining':'Choose a plan and submit your manual payment details.')),
   ]))),
   const SizedBox(height:12),
   const Text('Choose Subscription Plan',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
   RadioListTile<String>(value:'Monthly',groupValue:plan,title:const Text('Monthly — PKR 500'),onChanged:(v)=>setState(()=>plan=v!)),
   RadioListTile<String>(value:'Yearly',groupValue:plan,title:const Text('Yearly — PKR 5,000'),onChanged:(v)=>setState(()=>plan=v!)),
   const Divider(),
   const Text('Manual Payment',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
   DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Payment method'),items:const [DropdownMenuItem(value:'JazzCash',child:Text('JazzCash')),DropdownMenuItem(value:'Easypaisa',child:Text('Easypaisa'))],onChanged:(v)=>setState(()=>method=v!)),
   const SizedBox(height:8),
   FutureBuilder<String>(future:DB.i.setting(method.toLowerCase()+'_title',''),builder:(c,s)=>FutureBuilder<String>(future:DB.i.setting(method.toLowerCase()+'_number',''),builder:(c,n)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Text((s.data??'').isEmpty&&(n.data??'').isEmpty?'Payment account details have not been configured by the administrator yet.': '${s.data??''}\n${n.data??''}'))))),
   Text('Amount to pay: PKR ${price.toStringAsFixed(0)}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
   TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Account email')),
   TextField(controller:payer,decoration:const InputDecoration(labelText:'Payer name')),
   TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Payer mobile number')),
   TextField(controller:txn,decoration:const InputDecoration(labelText:'JazzCash / Easypaisa transaction ID')),
   const SizedBox(height:10),
   FilledButton(onPressed:submit,child:const Text('Submit Payment Request')),
   OutlinedButton(onPressed:approveLatest,child:const Text('Admin: Verify & Activate Latest Payment')),
   const Text('Manual payments are not automatically verified. An administrator must check the transaction receipt before approving.'),
   if(widget.expired)OutlinedButton(onPressed:()=>Navigator.pushReplacement(c,MaterialPageRoute(builder:(_)=>const Login())),child:const Text('Back to Login')),
  ])
 );
}


class SettingsPage extends StatefulWidget{const SettingsPage({super.key});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage>{
 final shop=TextEditingController(),user=TextEditingController(),pin=TextEditingController(),jt=TextEditingController(),jn=TextEditingController(),et=TextEditingController(),en=TextEditingController();
 @override void initState(){super.initState();load();}
 Future<void>load()async{
  for(final x in [('shop',shop),('user',user),('pin',pin),('jazzcash_title',jt),('jazzcash_number',jn),('easypaisa_title',et),('easypaisa_number',en)]){x.$2.text=await DB.i.setting(x.$1,'');}
  if(mounted)setState((){});
 }
 Future<void>save()async{
  for(final x in [('shop',shop.text),('user',user.text),('pin',pin.text),('jazzcash_title',jt.text),('jazzcash_number',jn.text),('easypaisa_title',et.text),('easypaisa_number',en.text)]){await DB.i.setSetting(x.$1,x.$2);}
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Settings saved')));
 }
 @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Settings',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  TextField(controller:shop,decoration:const InputDecoration(labelText:'Shop name')),
  TextField(controller:user,decoration:const InputDecoration(labelText:'Admin username')),
  TextField(controller:pin,decoration:const InputDecoration(labelText:'Admin password / PIN')),
  const SizedBox(height:16),const Text('Manual Subscription Payment Accounts',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
  TextField(controller:jt,decoration:const InputDecoration(labelText:'JazzCash account title')),
  TextField(controller:jn,decoration:const InputDecoration(labelText:'JazzCash account number')),
  TextField(controller:et,decoration:const InputDecoration(labelText:'Easypaisa account title')),
  TextField(controller:en,decoration:const InputDecoration(labelText:'Easypaisa account number')),
  const SizedBox(height:12),
  FilledButton(onPressed:save,child:const Text('Save Settings')),
  OutlinedButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const SubscriptionPage())),child:const Text('Open Subscription & Payment Requests')),
  const Text('Subscription: 7-day trial • Monthly PKR 500 • Yearly PKR 5,000 • Manual JazzCash / Easypaisa'),
  const Text('Developer: Muhammad Ilyas')
 ]);
}
