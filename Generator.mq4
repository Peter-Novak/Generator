/*
**************************************************************************************************************************************************************************************************************************
*                                                                                                                                                                                                                        *
* Generator.mq4                                                                                                                                                                                                              *
*                                                                                                                                                                                                                        *
* Copyright Peter Novak ml., M.Sc.                                                                                                                                                                                       *
**************************************************************************************************************************************************************************************************************************
*/

#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"

/*
Opis delovanja algoritma in uporaba podatkovnih struktur
========================================================
Algoritem naj bi generiral 100 točk profita dnevno, temelji pa na lastnosti cene, da se odmika od cene odprtja. Ob začetku dneva izberemo ceno odprtja dneva. Ob tej ceni odpremo eno BUY in eno SELL pozicijo. Nato
čakamo, da se cena oddalji d točk od cene odprtja. Pozicijo, ki je negativna takrat zapremo. Nato imamo dve možnosti:

  (1) ostala pozicija doseže profitni cilj;
  (2) cena se vrne nazaj na ceno odprtja dneva.
  
V primeru (1) je trgovanje za ta dan zaključeno. V primeru (2), profitni cilj povečamo za realizirano izgubo in algoritem začnemo od začetka.
*/



// Vhodni parametri --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern double d;                        // Razdalja d.
extern double L;                        // Velikost posamezne pozicije v lotih.
extern double p;                        // Profitni cilj.
extern int    stevilkaIteracije;        // Številka iteracije.
extern int    samodejniPonovniZagon;    // Samodejni ponovni zagon - DA(>0) ali NE(0). 



// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define NAPAKA     -1   // Oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije.
#define S0          1   // Oznaka za stanje S0CakanjeNaZagon
#define S1          2   // Oznaka za stanje S1CakanjeNaSmer
#define S2          3   // Oznaka za stanje S2Nakup
#define S3          4   // Oznaka za stanje S3Prodaja
#define S4          5   // Oznaka za stanje S4Zaključek
#define USPEH      -6   // Oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije.



// Globalne spremenljivke --------------------------------------------------------------------------------------------------------------------------------------------------------------
int      bpozicija;          // Enolične oznake vseh odprtih nakupnih pozicij.
int      spozicija;          // Enolične oznake vseh odprtih prodajnih pozicij.
int      stanje;             // Trenutno stanje algoritma.
int      verzija=1;          // Trenutna verzija algoritma.
double   cenaOdprtja;        // Cena ob odprtju dneva.
double   ciljZgoraj;         // Profitni cilj na strani BUY.
double   ciljSpodaj;         // Profitni cilj na strani SELL.
double   izkupicek;          // Izkupiček trenutne iteracije algoritma (izkupiček zaprtih pozicij, vseh niti).
double   maxIzpostavljenost; // Največja izguba algoritma (minimum od izkupicek).
double   vrednostPozicij;    // Skupna vrednost vseh pozicij, hranimo jo v spremenljivki da zmanjšamo računsko intenzivnost algoritma.
datetime casZadnjeSvece;     // Čas odprtja zadnje sveče


/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* GLAVNI PROGRAM in obvezne funkcije: init, deinit, start                                                                                                                              *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: deinit  
----------------
(o) Funkcionalnost: Sistem jo pokliče ob zaustavitvi. M5 je ne uporablja
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/   
int deinit() { return( USPEH ); } // deinit 



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: init  
--------------
(o) Funkcionalnost: Sistem jo pokliče ob zagonu. V njej izvedemo naslednje:
  (-) izpišemo pozdravno sporočilo;
  (-) ponastavimo vse podatkovne strukture algoritma na začetne vrednosti;
  (-) začnemo novo iteracijo algoritma.
(o) Zaloga vrednosti: USPEH, NAPAKA
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int init()
{
  stanje            =S0; 
  izkupicek         =0;
  maxIzpostavljenost=0;
  vrednostPozicij   =0;
  casZadnjeSvece    =Time[0];
 
  Print( "****************************************************************************************************************" );
  Print( "Dober dan. Tukaj Generator, verzija ", verzija, "." );
  Print( "****************************************************************************************************************" );

  return( USPEH );
} // init



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  
---------------
(o) Funkcionalnost: Glavna funkcija, ki upravlja celoten algoritem - sistem jo pokliče ob vsakem ticku. 
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int start()
{
  int trenutnoStanje; // zabeležimo trenutno stanje za ugotavljanje spremembe stanja.
  
  trenutnoStanje=stanje;
  switch( stanje )
  {
    case S0: stanje=S0CakanjeNaZagon(); break;
    case S1: stanje=S1CakanjeNaSmer();  break;
    case S2: stanje=S2Nakup();          break;
    case S3: stanje=S3Prodaja();        break;
    case S4: stanje=S4Zakljucek();      break;
    default: Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:start:OPOZORILO: Stanje ", stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
  }
  if( trenutnoStanje!=stanje ) // Če je prišlo do prehoda med stanji, izpišemo obvestilo.
  { 
    Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:Prehod: ", ImeStanja( trenutnoStanje ), " ===========>>>>> ", ImeStanja( stanje ) ); 
  }

  if( maxIzpostavljenost > izkupicek ) // Če se je poslabšala izpostavljenost, to zabeležimo in izpišemo obvestilo.
  { 
    maxIzpostavljenost=izkupicek; 
    Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", "Nova največja izpostavljenost: ", DoubleToString( maxIzpostavljenost, 5 ) ); 
  }
    
  // Prikaz ključnih kazalnikov delovanja algoritma na zaslonu.
  Comment( "Izkupiček: "               , DoubleToString( izkupicek,          5 ), "\n",
           "Največja izpostavljenost: ", DoubleToString( maxIzpostavljenost, 5 ), "\n",
           "Cilj zgoraj: "             , DoubleToString( ciljZgoraj,         5 ), "\n",
           "Cilj spodaj: "             , DoubleToString( ciljSpodaj,         5 ), "\n"
         );         
  return( USPEH );
} // start



/*
**************************************************************************************************************************************************************************************************************************
*                                                                                                                                                                                                                        *
* POMOŽNE FUNKCIJE                                                                                                                                                                                                       *
* Urejene po abecednem vrstnem redu                                                                                                                                                                                      *
**************************************************************************************************************************************************************************************************************************
*/



/*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja( int KodaStanja )
-------------------------------------
(o) Funkcionalnost: Na podlagi numerične kode stanja, vrne opis stanja.  
(o) Zaloga vrednosti: imena stanj
(o) Vhodni parametri: KodaStanja: enolična oznaka stanja. 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string ImeStanja( int KodaStanja )
{
  switch( KodaStanja )
  {
    case S0: return( "S0 - CAKANJE NA ZAGON" );
    case S1: return( "S1 - CAKANJE NA SMER"  );
    case S2: return( "S2 - NAKUP"            );
    case S3: return( "S3 - PRODAJA"          );
    case S4: return( "S4 - ZAKLJUČEK"        ); 
    default: Print ( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":ImeStanja:OPOZORILO: Koda stanja ", KodaStanja, " ni prepoznana. Preveri pravilnost delovanja algoritma." );
  }
  
  return( NAPAKA );
} // ImeStanja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo( int smer )
----------------------------------------------------
(o) Funkcionalnost: Odpre pozicijo po trenutni tržni ceni v podani Smeri.
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
 (-) smer: OP_BUY ali OP_SELL.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriPozicijo( int smer )
{
  int magicNumber; // spremenljivka, ki hrani magic number pozicije
  int rezultat;    // spremenljivka, ki hrani rezultat odpiranja pozicije
  string komentar; // spremenljivka, ki hrani komentar za pozicijo
 
  // Za primer da bi se izvajanje algoritma med izvajanjem nepričakovano ustavilo, vsako pozicijo označimo, da jo kasneje lahko prepoznamo in vzpostavimo stanje algoritma nazaj.
  magicNumber=stevilkaIteracije*1000;
  komentar   =StringConcatenate( "GEN", verzija, "-", magicNumber );

  // Zanka v kateri odpiramo pozicije. Vztrajamo, dokler nam ne uspe.
  do
    {
      if( smer == OP_BUY ) { rezultat = OrderSend( Symbol(), OP_BUY,  L, Ask, 0, 0, 0, komentar, magicNumber, 0, Green ); }
      else                 { rezultat = OrderSend( Symbol(), OP_SELL, L, Bid, 0, 0, 0, komentar, magicNumber, 0, Red   ); }
      if( rezultat == -1 ) 
        { 
          Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":OdpriPozicijo:NAPAKA: neuspešno odpiranje pozicije. Ponoven poskus čez 30s..." ); 
          Sleep( 30000 );
          RefreshRates();
        }
    }
  while( rezultat == -1 );
  
  return( rezultat );
} // OdpriPozicijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdprtaJeBilaNovaSveca()
---------------------------------
(o) Funkcionalnost: Vrne true, če je bila od zadnjega klica odprta nova sveča.
(o) Zaloga vrednosti: true / false
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool OdprtaJeBilaNovaSveca()
{
  if( casZadnjeSvece!=Time[0] )
  {
    casZadnjeSvece=Time[0];
    Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":OdprtaJeBilaNovaSveca: odprta je bila nova sveča." ); 
    return(true);
  }
  else
  {
    return(false);
  }
} // OdprtaJeBilaNovaSveca



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicije( int id )
------------------------------------
(o) Funkcionalnost: Vrne vrednost pozicije z oznako id v točkah
(o) Zaloga vrednosti: vrednost pozicije v točkah
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostPozicije( int id )
{
  bool rezultat;
  int  vrstaPozicije;
  
  rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( rezultat == false ) { Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":VrednostPozicije:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( 0 ); }
  
  vrstaPozicije = OrderType();
  switch( vrstaPozicije )
  {
    case OP_BUY : if( OrderCloseTime() == 0 ) { return( Bid - OrderOpenPrice() ); } else { return( OrderClosePrice() - OrderOpenPrice()  ); }
    case OP_SELL: if( OrderCloseTime() == 0 ) { return( OrderOpenPrice() - Ask ); } else { return(  OrderOpenPrice() - OrderClosePrice() ); }
    default     : Print( "SuperChargerMulti-V", verzija, ":[", stevilkaIteracije, "]:", ":VrednostPozicije:NAPAKA: Vrsta ukaza ni ne BUY ne SELL. Preveri pravilnost delovanja algoritma." ); return( 0 );
  }
} // VrednostPozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicijo( int id )
---------------------------------
(o) Funkcionalnost: Zapre pozicijo z oznako id po trenutni tržni ceni. Če zapiranje ni bilo uspešno, počaka 5 sekund in poskusi ponovno. Če v 20 poskusih zapiranje ni uspešno, 
                    potem pošljemo sporočilo, da naj uporabnik pozicijo zapre ročno.
(o) Zaloga vrednosti:
 (-) true: če je bilo zapiranje pozicije uspešno;
 (-) false: če zapiranje pozicije ni bilo uspešno; 
(o) Vhodni parametri: id - oznaka pozicije.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ZapriPozicijo( int id )
{
  int Rezultat;     // hrani rezultate klicev OrderSelect in OrderClose
  int stevec;       // šteje število poskusov zapiranja pozicije
  string obvestilo; // hrani tekst obvestila v primeru neuspešnega zapiranja

  // poiščemo pozicijo id
  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":ZapriPozicijo::NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( false ); }
  
  // pozicijo smo našli
  Rezultat = false;
  stevec   = 0;
  while( ( Rezultat == false ) && ( stevec < 20 ) )
  { 
    switch( OrderType() )
    {
      case OP_BUY : 
        Rezultat = OrderClose ( id, OrderLots(), Bid, 0, Green );
        break;
      case OP_SELL:
        Rezultat = OrderClose ( id, OrderLots(), Ask, 0, Red   );
        break;
      default: 
        return( OrderDelete( id ) );
    }
    if( Rezultat == true ) 
      { Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":LOG:ZapriPozicijo:: Pozicija ", id, " uspešno zaprta. Število poskusov: ", stevec+1 ); return( true );  }
    else
      { Print( "Generator-V", verzija, ":[", stevilkaIteracije, "]:", ":OPOZORILO:ZapriPozicijo:: Zapiranje pozicije ", id, " neuspešno. Število opravljenih poskusov: ", stevec+1 ); Sleep( 5000 ); stevec++; }
  }
  
  // če smo prišli do sem, pomeni da tudi po 20 poskusih zapiranje ni bilo uspešno, zato pošljemo obvestilo da je potrebno pozicijo zapreti ročno
  obvestilo = "Generator-V" + IntegerToString( verzija ) + ":[" + IntegerToString( stevilkaIteracije ) + "]:" + Symbol() + "POMEMBNO: zapiranje pozicije ni bilo uspešno. Ročno zapri pozicijo " + IntegerToString( id );
  SendNotification( obvestilo );
  return( false );
} // ZapriPozicijo



/*
**************************************************************************************************************************************************************************************************************************
*                                                                                                                                                                                                                        *
* FUNKCIJE DKA                                                                                                                                                                                                           *
*                                                                                                                                                                                                                        *
**************************************************************************************************************************************************************************************************************************
*/



/*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S0CakanjeNaZagon() 
-------------------------
(1) Opis faze "Čakanje na zagon"
--------------------------------
V tej fazi čakamo da se odpre nova dnevna sveča. Ko se to zgodi naredimo naslednje:
  (1) zapomnimo si ceno odprtja;
  (2) odpremo obe poziciji;
  (3) izračunamo cilj spodaj in cilj zgoraj.

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S0CakanjeNaZagon()
{
  // Preverimo ali je bila odprta nova sveča
  // if( OdprtaJeBilaNovaSveca()==true )  
  // {
     cenaOdprtja=Bid;
     bpozicija  =OdpriPozicijo(OP_BUY );
     spozicija  =OdpriPozicijo(OP_SELL);
     ciljSpodaj =Bid-d;
     ciljZgoraj =Bid+d;
     return(S1);
  // }
  // Če nobeno pogoj za prehod ni izpolnjen, ostanemo v stanju S0.
  // return( S0 );
} // S0CakanjeNaZagon



/*------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1CakanjeNaSmer()
-------------------------------
(2) Opis faze "čakanje na smer"
-----------------------------
V tej fazi čakamo da je dosežen bodisi cilj spodaj ali cilj zgoraj:
  (1) dosežen je cilj spodaj;
  (2) dosežen je cilj zgoraj.
V primeru (1) naredimo naslednje:
  (-) zapremo buy pozicijo;
  (-) cilj spodaj in cilj zgoraj povečamo za izgubo zaprte buy pozicije;
  (-) gremo v stanje S3Prodaja.
V primeru (2) naredimo naslednje:
  (-) zapremo sell pozicijo;
  (-) cilj spodaj in cilj zgoraj povečamo za izgubo zaprte sell pozicije;
  (-) gremo v stanje S2Nakup.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1CakanjeNaSmer()
{ 
  double vrednost;
  
  // Preverimo ali je dosežen cilj spodaj
  if( Bid<cenaOdprtja-d )  
  { 
    ZapriPozicijo(bpozicija);
    vrednost  =MathAbs(VrednostPozicije(bpozicija));
    izkupicek =izkupicek-vrednost;
    ciljSpodaj=ciljSpodaj-vrednost;
    ciljZgoraj=ciljZgoraj+vrednost;
    return(S3);
  }
  // Preverimo ali je dosežen cilj zgoraj
  if( Bid>cenaOdprtja+d )  
  { 
    ZapriPozicijo(spozicija);
    vrednost  =MathAbs(VrednostPozicije(spozicija));
    izkupicek =izkupicek-vrednost;
    ciljSpodaj=ciljSpodaj-vrednost;
    ciljZgoraj=ciljZgoraj+vrednost;
    return(S2);
  }
  // Sicer ostanemo v tem stanju
  return( S1 );
} // S1CakanjeNaSmer



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Nakup()
-----------------------
V tem stanju čakamo da se zgodi eno od naslednjega:
  (1) dosežen je profitni cilj;
  (2) cena je dosegla ceno odprtja.
V primeru (1) naredimo naslednje:
  (-) zapremo buy pozicijo;
  (-) gremo v stanje S4 zaključek.
V primeru (2) naredimo naslednje:
  (-) odpremo sell pozicijo;
  (-) gremo v stanje S1 čakanje na smer.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Nakup()
{
  // Preverimo ali je dosežen profitni cilj
  if( VrednostPozicije(bpozicija)+izkupicek>p )
  {
    ZapriPozicijo(bpozicija);
    return(S4);
  }
  // Preverimo ali je cena dosegla ceno odprtja
  if( Bid<=cenaOdprtja ) 
  {
    spozicija=OdpriPozicijo(OP_SELL);
    return(S1);
  }
  // V nasprotnem primeru ostanemo v S2
  return(S2);
} // S2Nakup



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S3Prodaja()
-------------------------
V tem stanju čakamo da se zgodi eno od naslednjega:
  (1) dosežen je profitni cilj;
  (2) cena je dosegla ceno odprtja.
V primeru (1) naredimo naslednje:
  (-) zapremo sell pozicijo;
  (-) gremo v stanje S4 zaključek.
V primeru (2) naredimo naslednje:
  (-) odpremo buy pozicijo;
  (-) gremo v stanje S1 čakanje na smer.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S3Prodaja()
{
  // Preverimo ali je dosežen profitni cilj
  if( VrednostPozicije(spozicija)+izkupicek>p )
  {
    ZapriPozicijo(spozicija);
    return(S4);
  }
  // Preverimo ali je cena dosegla ceno odprtja
  if( Bid>=cenaOdprtja ) 
  {
    bpozicija=OdpriPozicijo(OP_BUY);
    return(S1);
  }
  // V nasprotnem primeru ostanemo v S3
  return(S3);
} // S3Nakup



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S4Zakljucek()
----------------------------
V tem stanju ponastavimo podatkovne strukture algoritma in algoritem zaženemo ponovno.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S4Zakljucek()
{ 
  if( samodejniPonovniZagon > 0 ) { init(); stevilkaIteracije++; return( S0 ); } else { return( S4 ); }
} // S3Zakljucek
