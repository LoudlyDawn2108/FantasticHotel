-- =============================================
-- HOTEL MANAGEMENT SYSTEM DATABASE
-- SQL Server Implementation
-- =============================================

-- Create Database
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'HotelManagement')
BEGIN
    ALTER DATABASE HotelManagement SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HotelManagement;
END
GO

CREATE DATABASE HotelManagement;
GO

USE HotelManagement;
GO

PRINT 'Database HotelManagement created successfully.';
GO
