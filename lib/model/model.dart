import 'dart:async';
import 'dart:convert';

import 'package:fumettologo_frontend/model/supports/constants.dart';
import 'package:fumettologo_frontend/model/supports/login_result.dart';
import 'package:http/http.dart' as http;
import 'objects/authentication_data.dart';
import 'objects/comic.dart';
import 'objects/cart_detail.dart';
import 'objects/order.dart';
import 'objects/registration_request.dart';
import 'objects/user.dart';

class Model {
  static Model sharedInstance = Model();
  AuthenticationData? _authenticationData; // dati autenticazione dell'utente
  String? _token; // token di accesso

  // metodo per registrare un nuovo utente
  Future<void> register(RegistrationRequest registrationRequest) async {
    // URL per la registrazione
    const String url = "${Constants.addressStoreServer}/register";
    // converte la richiesta di registrazione in formato JSON
    final Map<String, dynamic> requestBody = registrationRequest.toJson();
    try {
      // effettua la richiesta POST
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      // verifica lo stato della risposta
      if (response.statusCode != 201) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per effettuare l'accesso
  Future<LoginResult> login(String email, String password) async {
    // corpo della richiesta per il login
    final Map<String, String> body = {
      'grant_type': 'password',
      'client_id': Constants.clientId,
      'username': email,
      'password': password
    };
    // effettua la richiesta POST
    final response = await http.post(
      Uri.parse(Constants.addressAuthenticationServer+Constants.requestLogin),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    // verifica dello stato della risposta
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      _authenticationData = AuthenticationData.fromJson(data);
      _token = _authenticationData!.accessToken;
      // imposta un timer per aggiornare il token
      Timer.periodic(
          Duration(seconds: (_authenticationData!.expiresIn - 60)), (
          Timer t) {
        _refreshToken();
      });
      return LoginResult.logged;
    }
    else if (response.statusCode == 401){
      return LoginResult.wrongCredentials;
    }
    else {
      return LoginResult.unknownError;
    }
  }

  // metodo per verificare se l'utente è loggato
  bool isLogged() {
    return _token != null;
  }

  // metodo per aggiornare il token di atuenticazione
  Future<bool> _refreshToken() async {
    try {
      // corpo della richiesta per aggiornare il token
      Map<String, String> body = {
        'grant_type': 'refresh_token',
        'client_id': Constants.clientId,
        'refresh_token': _authenticationData!.refreshToken
      };
      // effettua la richiesta POST
      final response = await http.post(
        Uri.parse(Constants.addressAuthenticationServer+Constants.requestLogin),
        headers: {'Content-Type': 'application/x-www-form-urlencoded',},
        body: body,
      );// verifica lo stato della risposta
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _authenticationData = AuthenticationData.fromJson(data);
        _token = _authenticationData!.accessToken;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // metodo per effettuare il logout dell'utente
  Future<bool> logOut() async {
    try{
      Map<String, String> params = {};
      _token = null;
      params["client_id"] = Constants.clientId;
      params["refresh_token"] = _authenticationData!.refreshToken;
      // effettua la richiesta POST per il logout
      final response = await http.post(
        Uri.parse(Constants.addressAuthenticationServer+Constants.requestLogout),
        headers: {'Content-Type': 'application/x-www-form-urlencoded',},
        body: params
      );
      return (response.statusCode == 204);
    }
    catch (e) {
      return false;
    }
  }

  // metodo per recuperare una lista di fumetti
  Future<List<Comic>> getComics({int pageNumber = 0, int pageSize = 5, String sortBy = 'id',}) async {
    final Uri uri = Uri.parse('${Constants
        .addressStoreServer}/comic?pageNumber=$pageNumber&pageSize=$pageSize&sortBy=$sortBy');
    try {
      // effettua la richiesta GET per recuperare la lista di fumetti
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Comic> comics = data.map((item) => Comic.fromJson(item)).toList();
        return comics;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to load comics');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per recuperare una lista di fumetti filtrati per titolo
  Future<List<Comic>> getComicsByTitle(String title, {int pageNumber = 0, int pageSize = 5, String sortBy = 'id'}) async {
    final Uri uri = Uri.parse('${Constants.addressStoreServer}/comic/title?title=$title&pageNumber=$pageNumber&pageSize=$pageSize&sortBy=$sortBy');
    try {
      // effettua la richiesta GET per recuperare la lista dei fumetti filtrati per titolo
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Comic> comics = data.map((item) => Comic.fromJson(item)).toList();
        return comics;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to load comics');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per filtrare i fumetti in base a vari criteri
  Future<List<Comic>> filter({
    String title = "", String author = "",
    String publisher = "", String category = "",
    int pageNumber = 0, int pageSize = 10, String sortBy = 'id',
  }) async {
    final Map<String, String> queryParams = {
      'title': title,
      'author': author,
      'publisher': publisher,
      'category': category,
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      'sortBy': sortBy,
    };
    final Uri uri = Uri.parse(
        '${Constants.addressStoreServer}/comic/filter').replace(
        queryParameters: queryParams);
    try {
      // richiesta GET
      final response = await http.get(uri);
      print(response);
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Comic> comics = data.map((item) => Comic.fromJson(item)).toList();
        return comics;
      } else if (response.statusCode == 404) {
        return [];
      }
      else {
        throw Exception('Failed to load comics');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per recuperare il profilo dell'utente loggato
  Future<User> fetchUserProfile() async {
    final url = Uri.parse('${Constants.addressStoreServer}/profile');
    try {
      // richiesta GET
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final user = User.fromJson(jsonData);
        return user;
      } else if (response.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per recuperare la lista degli ordini dell'utente loggato
  Future<List<Order>> getUserOrders() async {
    final url = Uri.parse('${Constants.addressStoreServer}/profile/orders');
    try {
      // richiesta GET
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final List<Order> orders = jsonData.map((data) =>
            Order.fromJson(data))
            .toList();
        return orders;
      } else if (response.statusCode == 404) {
        throw Exception('No orders found');
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per recuperare i dettagli del carrello dell'utente loggatto
  Future<List<CartDetail>> getCartDetails() async {
    final url = Uri.parse('${Constants.addressStoreServer}/profile/cart');
    try {
      // richiesta GET
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final List<CartDetail> cartDetails = jsonData.map((data) =>
            CartDetail.fromJson(data)).toList();
        return cartDetails;
      }
      else {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per svuotare il carrello dell'utente loggato
  Future<void> clearCart() async {
    final url = Uri.parse('${Constants.addressStoreServer}/profile/cart');
    try {
      // DELETE
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per rimuovere un elemento dal carrello dell'utente
  Future<void> removeItem(int itemId) async {
    final url = Uri.parse(
        '${Constants.addressStoreServer}/profile/cart/$itemId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per aggiornare la quantità di un elemento nel carrello dell'utente loggato
  Future<void> updateItemQuantity(int itemId, int quantity) async {
    final url = Uri.parse(
        '${Constants.addressStoreServer}/profile/cart/$itemId');
    final Map<String, String> body = {
      'quantity': quantity.toString(),
    };
    try {
      // PUT
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
        body: body
      );
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per aggiungere un fumetto al carrello dell'utente loggato
  Future<void> addToCart(int comicId) async {
    final url = Uri.parse('${Constants.addressStoreServer}/profile/cart');
    final Map<String, String> body = {
      'comicId': comicId.toString(),
    };
    try {
      final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $_token',
          },
          body: body
      );
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  // metodo per effettuare il checkout del carrello
  Future<void> checkout(List<CartDetail> cartDetails) async {
    final url = Uri.parse("${Constants.addressStoreServer}/profile/cart/checkout");

    try {
      final body = jsonEncode(cartDetails.map((detail) => detail.toJson()).toList());
      final response = await http.post(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 201) {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception(e);
    }
  }
}