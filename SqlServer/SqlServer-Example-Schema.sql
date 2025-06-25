CREATE DATABASE MermaidTest;
GO

USE MermaidTest;
GO

-- 1-to-1 relationship between Person and Employee
-- and between Person and Customer
CREATE TABLE Person (
    ID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100)
);

CREATE TABLE Employee (
    ID INT PRIMARY KEY,
    FOREIGN KEY (ID) REFERENCES Person(ID)
);

CREATE TABLE Customer (
    ID INT PRIMARY KEY,
    FOREIGN KEY (ID) REFERENCES Person(ID)
);

-- 1-to-many relationship between Customer and Order
CREATE TABLE [Order] (
    ID INT PRIMARY KEY,
    CustomerID INT,
    OrderDate DATETIME,
    FOREIGN KEY (CustomerID) REFERENCES Customer(ID)
);

-- 1-to-many relationship with in Order for OrderItem using a composite key
CREATE TABLE Product (
    ID INT PRIMARY KEY,
    Name NVARCHAR(100),
    Price DECIMAL(10, 2)
);

CREATE TABLE OrderItem (
    OrderID INT,
    ProductID INT,
    Quantity INT,
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID) REFERENCES [Order](ID),
    FOREIGN KEY (ProductID) REFERENCES Product(ID)
);



