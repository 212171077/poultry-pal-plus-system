import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poultry_pal_plus_app/models/message_response.dart';

import '../models/growing_phase.dart';
import '../models/settings_data.dart';
import '../models/user.dart';

class PoultryPalService {
    //final String authBaseUrl = 'http://10.0.2.2:8090/api/auth';
    //final String farmBaseUrl = 'http://10.0.2.2:8090/api/farm';

    //final String authBaseUrl = 'http://192.168.1.106:8090/api/auth';
    //final String farmBaseUrl = 'http://192.168.1.106:8090/api/farm';

    final String authBaseUrl = 'http://154.0.166.216:8090/api/auth';
    final String farmBaseUrl = 'http://154.0.166.216:8090/api/farm';


    //final String authBaseUrl = 'https://tertiaryverify.dedicated.co.za:8090/api/auth';
    //final String farmBaseUrl = 'https://tertiaryverify.dedicated.co.za:8090/api/farm';

    final Dio dio;

    static final PoultryPalService _instance = PoultryPalService._internal();

    factory PoultryPalService() => _instance;

    PoultryPalService._internal() : dio = _initializeDio();

    static Dio _initializeDio() {
        final CookieJar cookieJar = CookieJar();
        final dio = Dio();
        dio.httpClientAdapter = IOHttpClientAdapter();
        dio.interceptors.add(CookieManager(cookieJar));
        return dio;
    }

    Future<MessageResponse> signup({
        required String name,
        required String surname,
        required String email,
        required String phoneNumber,
        required String password,
        required String farmName,
    }) async {
        final url = Uri.parse('$authBaseUrl/signup');

        final Map<String, dynamic> requestBody = {
            "name": name,
            "surname": surname,
            "email": email,
            "phoneNumber": phoneNumber,
            "password": password,
            "farmName": farmName,
        };

        try {
            final response = await http.post(
                url,
                headers: {
                    'Content-Type': 'application/json',
                    'accept': '*/*',
                },
                body: jsonEncode(requestBody),
            );

            if (response.statusCode == 200 || response.statusCode == 400) {
                // Parse the response body and return a MessageResponse object
                final responseData = jsonDecode(response.body);
                return MessageResponse.fromJson(responseData);
            } else {
                // Handle other status codes
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } catch (e) {
            // Handle network or other errors
            return MessageResponse(
                success: false, message: "Error during signup: $e");
        }
    }

    Future<User> login(String email, String password) async {
        try {
            final response = await dio.post(
                '$authBaseUrl/signin',
                data: {
                    "username": email,
                    "password": password,
                },
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            final user = User.fromJson(response.data);
            await SessionManager().set("userData", jsonEncode(response.data));
            await fetchFarmDetails(user.farmId);

            return user;
        } catch (e) {
            print('Login failed: $e');
            rethrow;
        }
    }

    Future<void> fetchFarmDetails(String farmId) async {
        try {
            final farmResponse = await dio.get(
                '$farmBaseUrl/find-farm-by-id/$farmId',
                options: Options(
                    headers: {
                        'accept': '*/*',
                    },
                ),
            );

            await SessionManager().set("farmData", jsonEncode(farmResponse.data));
        } catch (e) {
            print('Failed to fetch or store farm data: $e');
            rethrow;
        }
    }

    Future<MessageResponse> deleteFarmCoop(String farmId, String coopId) async {
        try {
            final response = await dio.delete(
                '$farmBaseUrl/delete-farm-coop/$farmId/$coopId',
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true, message: "Coop deleted successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "We are unable to delete the coop, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "We are unable to delete the coop, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "We are unable to delete the coop, please try again.");
        }
    }

    Future<MessageResponse> updateFarmCoop({
        required String farmId,
        required String? coopId,
        required String coopName,
        required String coopType,
        required GrowingPhase growthPhase,
        required int numberOfChickens,
        required String? chickenArrivalDate,
    }) async {

        final Map<String, dynamic> requestBody = {
            "farmId": farmId,
            "coopId": coopId,
            "coopName": coopName,
            "coopType": coopType.toUpperCase(),
            "growthPhase": growthPhase.name,
            "numberOfChickens": numberOfChickens,
            "chickenArrivalDate": chickenArrivalDate,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-farm-coop',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "Coop added");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding/updating coop, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while adding/updating coop, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding/updating coop, please try again.");
        }
    }

    Future<MessageResponse> addNewBatch({
        required String farmId,
        required String? coopId,
        required String coopName,
        required String coopType,
        required GrowingPhase growthPhase,
        required int numberOfChickens,
        required String? chickenArrivalDate,
    }) async {
        final Map<String, dynamic> requestBody = {
            "farmId": farmId,
            "coopId": coopId,
            "coopName": coopName,
            "coopType": coopType.toUpperCase(),
            "growthPhase": growthPhase.name,
            "numberOfChickens": numberOfChickens,
            "chickenArrivalDate": chickenArrivalDate,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/add-new-batch',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "New batch added");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding new batch, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while adding new batch, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding new batch, please try again.");
        }
    }

    Future<MessageResponse> updateSales({
        required String? id,
        required String farmId,
        required String? coopId,
        required int? numberOfDozensSold,
        required double? salePricePerDozen,
        required int? numberOfChickensSold,
        required double? salePricePerChicken,
        required String buyerName,
        required String recordedBy,
        required String paymentStatus,
        required String saleDate,
    }) async {
        final Map<String, dynamic> requestBody = {
            "id": id,
            "farmId": farmId,
            "coopId": coopId,
            "numberOfDozensSold": numberOfDozensSold,
            "salePricePerDozen": salePricePerDozen,
            "numberOfChickensSold": numberOfChickensSold,
            "salePricePerChicken": salePricePerChicken,
            "buyerName": buyerName,
            "recordedBy": recordedBy,
            "paymentStatus": paymentStatus.toUpperCase(),
            "saleDate": saleDate,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-sales',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "Sale added");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding/updating sale, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while adding/updating sale, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding/updating sale, please try again.");
        }
    }

    Future<MessageResponse> updateMortality(
    {required String? id,
        required String farmId,
        required String? coopId,
        required String dateOccurred,
        required int? numberOfDeaths,
        required String reason,
        required String recordedBy}) async {
        final Map<String, dynamic> requestBody = {
            "id": id,
            "farmId": farmId,
            "coopId": coopId,
            "dateOccurred": dateOccurred,
            "numberOfDeaths": numberOfDeaths,
            "reason": reason,
            "recordedBy": recordedBy,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-mortalities',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "Mortality added");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding/updating mortality, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message:
                    "Error while adding/updating mortality, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding/updating mortality, please try again.");
        }
    }

    Future<MessageResponse> updateExpenses(
    {required String? id,
        required String farmId,
        required String coopId,
        required String expenseDate,
        required String expenseType,
        required double amount,
        required String additionalInfo,
        required String recordedBy}) async {
        final Map<String, dynamic> requestBody = {
            "id": id,
            "farmId": farmId,
            "coopId": coopId,
            "expenseDate": expenseDate,
            "expenseType": expenseType,
            "amount": amount,
            "additionalInfo": additionalInfo,
            "recordedBy": recordedBy,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-expense',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "Expense added");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding/updating expense, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while adding/updating expense, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding/updating expense, please try again.");
        }
    }

    Future<MessageResponse> updateUser(
    {required String id,
        required String farmId,
        required String name,
        required String surname,
        required String email,
        required String phoneNumber}) async {
        final Map<String, dynamic> requestBody = {
            "id": id,
            "farmId": farmId,
            "name": name,
            "surname": surname,
            "email": email,
            "phoneNumber": phoneNumber,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-user',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                final user = User.fromJson(response.data);
                await SessionManager().set("userData", jsonEncode(response.data));
                await fetchFarmDetails(user.farmId);

                MessageResponse messageResponse = MessageResponse(
                    success: true, message: "User details updated successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating personal details, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message:
                    "Error while updating personal details, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating personal details, please try again.");
        }
    }


    Future<MessageResponse> updateLoginDetails({
        required String userId,
        required String currentPassword,
        required String newPassword,
    }) async {
        final Map<String, dynamic> requestBody = {
            "userId": userId,
            "currentPassword": currentPassword,
            "newPassword": newPassword,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-login-details',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "Login details updated");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating login details, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while updating login details, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating login details, please try again.");
        }
    }

    Future<MessageResponse> updateFarmDetails({
        required String updatedByUserId,
        required String farmId,
        required String farmName,
        required String farmAddressLine1,
        required String farmAddressLine2,
        required String farmState,
        required String farmCity,
        required String farmPostalCode,
        required String farmCountry,
    }) async {
        final Map<String, dynamic> requestBody = {
            "updatedByUserId": updatedByUserId,
            "farmId": farmId,
            "farmName": farmName,
            "farmAddressLine1": farmAddressLine1,
            "farmAddressLine2": farmAddressLine2,
            "farmState": farmState,
            "farmCity": farmCity,
            "farmPostalCode": farmPostalCode,
            "farmCountry": farmCountry,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-farm-details',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "Farm details updated");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating farm details, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while updating farm details, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating farm details, please try again.");
        }
    }

    Future<MessageResponse> addFarmUser({
        required String addedByUserId,
        required String farmId,
        required String name,
        required String surname,
        required String email,
        required String phoneNumber,
        required List<String> roles,
    }) async {
        final Map<String, dynamic> requestBody = {
            "addedByUserId": addedByUserId,
            "farmId": farmId,
            "name": name,
            "surname": surname,
            "email": email,
            "phoneNumber": phoneNumber,
            "roles": roles,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/add-farm-user',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                    MessageResponse(success: true, message: "User added");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding user, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while adding user, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding user, please try again.");
        }
    }

    Future<MessageResponse> updateResponsibleUser({
        required String farmId,
        required String userId,
        required List<String> coopIds,
    }) async {
        final Map<String, dynamic> requestBody = {
            "coopIds": coopIds,
            "farmId": farmId,
            "userId": userId,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/add-responsible-user',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true, message: "User coops updated successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating user coops, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while updating user coops, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating user coops, please try again.");
        }
    }

    Future<MessageResponse> updateUserRoles({
        required String updatedByUserId,
        required String farmId,
        required String userId,
        required List<String> roles,
    }) async {
        final Map<String, dynamic> requestBody = {
            "updatedByUserId": updatedByUserId,
            "farmId": farmId,
            "userId": userId,
            "roles": roles,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-user-roles',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true, message: "User role updated successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating user roles, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while updating user roles, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating user roles, please try again.");
        }
    }

    Future<MessageResponse> removedUser({
        required String updatedByUserId,
        required String farmId,
        required String userId,
    }) async {
        final Map<String, dynamic> requestBody = {
            "deletedByUserId": updatedByUserId,
            "farmId": farmId,
            "userId": userId,
        };

        try {
            final response = await dio.delete(
                '$farmBaseUrl/remove-user',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true, message: "User removed successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while removing user, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while removing user, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while removing user, please try again.");
        }
    }

    Future<MessageResponse> deleteCoopItem(
    {required String farmId,
        required String coopId,
        required String deletedByUserId,
        required String itemType,
        required String itemId}) async {
        try {
            final Map<String, dynamic> requestBody = {
                "deletedByUserId": deletedByUserId,
                "farmId": farmId,
                "coopId": coopId,
                "itemId": itemId,
                "itemType": itemType.toUpperCase(),
            };

            final response = await dio.delete(
                '$farmBaseUrl/delete-coop-item',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true, message: "$itemType deleted successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "We are unable to delete the $itemType, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message:
                    "We are unable to delete the $itemType, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "We are unable to delete the $itemType, please try again.");
        }
    }

    Future<void> downloadReport(
    {required BuildContext context,
        required String farmId,
        required String userId}) async {
        final url = '$farmBaseUrl/download-report/$farmId/$userId';

        try {
            // Get the directory to save the file
            final directory = await getApplicationDocumentsDirectory();
            final filePath = '${directory.path}/report.pdf';

            // Download the file
            final response = await dio.download(url, filePath);

            if (response.statusCode == 200) {
                // Open the file with a viewer
                OpenFile.open(filePath);

                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report downloaded successfully! $filePath')),
                );
            } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to download report.')),
                );
            }
        } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('An error occurred: $error')),
            );
        }
    }

    Future<MessageResponse> sendReportViaEmail(
    {required String farmId, required String userId}) async {
        try {
            final Map<String, dynamic> requestBody = {
                "farmId": farmId,
                "userId": userId,
            };

            final response = await dio.post(
                '$farmBaseUrl/send-report',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                MessageResponse messageResponse = MessageResponse(
                    success: true,
                    message:
                    "Your farm report has been sent, please check your mail inbox");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "We are unable to send your farm report, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message:
                    "We are unable to send your farm report, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "We are unable to send your farm report, please try again.");
        }
    }

    Future<MessageResponse> updateReminder({
        required String id,
        required String updatedByUserId,
        required String farmId,
        required String coopId,
        required String reminderType,
        required String action,
        required String? actionComment,
    }) async {
        final Map<String, dynamic> requestBody = {
            "id": id,
            "updatedByUserId": updatedByUserId,
            "farmId": farmId,
            "coopId": coopId,
            "reminderType": reminderType,
            "action": action,
            "actionComment": actionComment,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-reminder',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true,
                    message: "$reminderType reminder updated successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating reminder, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while updating reminder, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating reminder, please try again.");
        }
    }

    Future<MessageResponse> performPhaseTransition({
        required String userId,
        required String farmId,
        required String currentCoopId,
        required String newCoopId,
        required GrowingPhase newGrowingPhase,
    }) async {
        final Map<String, dynamic> requestBody = {
            "userId": userId,
            "farmId": farmId,
            "currentCoopId": currentCoopId,
            "newCoopId": newCoopId,
            "newGrowingPhase": newGrowingPhase.name,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/growing-phase-transition',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true,
                    message: "Growing phase transition completed successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while performing growing phase transition, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message:
                    "Error while performing growing phase transition, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message:
                "Error while performing growing phase transition, please try again.");
        }
    }

    Future<MessageResponse> saveSettings(SettingsData settings) async {
        final Map<String, dynamic> requestBody = {
            "id": settings.id,
            "userId": settings.userId,
            "farmId": settings.farmId,
            "currency": settings.currency,
            "autoCreateReminders": settings.autoCreateReminders,
            "salesAlerts": settings.salesAlerts,
            "mortalityAlerts": settings.mortalityAlerts,
            "expenseAlerts": settings.expenseAlerts,
            "dailyReminders": settings.dailyReminders,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/update-user-setting',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse = MessageResponse(
                    success: true,
                    message: "User settings updated successfully");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while updating user settings, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message: "Error while updating user settings, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while updating user settings, please try again.");
        }
    }

    Future<SettingsData> loadSettings(String farmId, String userId) async {
        try {
            final response = await dio.get(
                '$farmBaseUrl/find-user-setting/$farmId/$userId',
                options: Options(
                    headers: {
                        'accept': '*/*',
                    },
                ),
            );
            return SettingsData.fromJson(response.data);
        } catch (e) {
            print('Failed to fetch user settings: $e');
            rethrow;
        }
    }

    Future<bool> sendScheduleEmail({
        required String userId,
        required String farmId,
        required String coopId,
    }) async {
        final Map<String, dynamic> requestBody = {
            "farmId": farmId,
            "userId": userId,
            "coopId": coopId,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/send-schedule',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );
            if (response.statusCode == 200) {
                return true;
            } else {
                return false;
            }
        } on DioException {
            return false;
        } catch (e) {
            return false;
        }
    }


    Future<MessageResponse> recordPackaging(
        {required String userId,
            required String farmId,
            required String coopId,
            required String eggSize,
            required String boxSize,
            required int numberOfBoxes,
            String? additionalInfo,
            String? createdDate,}) async {
        final Map<String, dynamic> requestBody = {
            "userId": userId,
            "farmId": farmId,
            "coopId": coopId,
            "eggSize": eggSize,
            "boxSize": boxSize,
            "numberOfBoxes": numberOfBoxes,
            "additionalInfo": additionalInfo,
            "createdDate": createdDate,
        };

        try {
            final response = await dio.post(
                '$farmBaseUrl/record-egg-packaging',
                data: jsonEncode(requestBody),
                options: Options(
                    headers: {
                        'Content-Type': 'application/json',
                        'accept': '*/*',
                    },
                ),
            );

            if (response.statusCode == 200) {
                await SessionManager().set("farmData", jsonEncode(response.data));
                MessageResponse messageResponse =
                MessageResponse(success: true, message: "Eggs recorded");
                return messageResponse;
            } else if (response.statusCode == 400) {
                final responseData = jsonDecode(response.data);
                return MessageResponse.fromJson(responseData);
            } else {
                return MessageResponse(
                    success: false, message: "An unknown error occurred.");
            }
        } on DioException catch (e) {
            if (e.response?.statusCode == 400) {
                return MessageResponse(
                    success: false,
                    message: e.response?.data['message'] ??
                        "Error while adding/updating eggs record, please try again.");
            } else {
                return MessageResponse(
                    success: false,
                    message:
                    "Error while adding/updating eggs record,, please try again.");
            }
        } catch (e) {
            return MessageResponse(
                success: false,
                message: "Error while adding/updating eggs record,, please try again.");
        }
    }

}
