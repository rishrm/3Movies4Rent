-- Run in a NEW test database. Existing databases are not dropped.
CREATE DATABASE `3Movies4Rent_A2_Test`;
USE `3Movies4Rent_A2_Test`;
CREATE TABLE PERSON (
    PersonID INTEGER,
    LastName CHAR(50),
    FirstName CHAR(50),
    Address CHAR(50),
    City CHAR(50),
    State CHAR(2),
    ZipCode CHAR(10),
    Telephone CHAR(15),
    PRIMARY KEY (PersonID)
) ENGINE=InnoDB;
CREATE TABLE CUSTOMER (
    PersonID INTEGER NOT NULL,
    CustomerID CHAR(11) NOT NULL,
    EmailAddress CHAR(50),
    CreditCardNumber CHAR(19),
    Rating INTEGER,
    PRIMARY KEY (CustomerID),
    UNIQUE (PersonID),
    FOREIGN KEY (PersonID) REFERENCES PERSON(PersonID)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    CHECK (Rating >= 1 AND Rating <= 5)
) ENGINE=InnoDB;
CREATE TABLE ACCOUNT (
    AccountNumber INTEGER,
    CustomerID CHAR(11) NOT NULL,
    AccountType CHAR(11) NOT NULL,
    AccountCreationDate DATE NOT NULL,
    PRIMARY KEY (AccountNumber),
    FOREIGN KEY (CustomerID) REFERENCES CUSTOMER(CustomerID)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
   CHECK (AccountType IN ('Lim', 'Unlim1', 'Unlim2', 'Unlim3'))
    ) ENGINE=InnoDB;
CREATE TABLE EMPLOYEE (
    SocialSecurityNumber CHAR(11),
    PersonID INTEGER NOT NULL,
    StartDate DATE,
    HourlyRate INTEGER,
    EmployeeType CHAR(25) NOT NULL,
    PRIMARY KEY (SocialSecurityNumber),
    UNIQUE (PersonID),
    FOREIGN KEY (PersonID) REFERENCES PERSON(PersonID)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    CHECK (HourlyRate >= 0),
    CHECK (EmployeeType IN ('Manager', 'CustomerRepresentative'))
) ENGINE=InnoDB;
CREATE TABLE MOVIE (
    MovieID INTEGER,
    MovieName CHAR(100) NOT NULL,
    MovieType CHAR(10) NOT NULL,
    DistributionFee DECIMAL(10,2),
    NumberOfCopies INTEGER NOT NULL,
    Rating INTEGER,
    PRIMARY KEY (MovieID),
    CHECK (MovieType IN('Comedy', 'Drama', 'Action', 'Foreign')),
    CHECK (DistributionFee >= 0),
    CHECK (NumberOfCopies >= 0),
    CHECK (Rating >= 1 AND Rating <=5)
) ENGINE=InnoDB;
CREATE TABLE ACTOR (
    ActorID INTEGER,
    ActorName CHAR(50),
    Gender CHAR(1),
    Age INTEGER,
    Rating INTEGER,
    PRIMARY KEY (ActorID),
    CHECK (Gender IN ('M', 'F')),
    CHECK (Age >= 0),
    CHECK (Rating >= 1 AND Rating <=5)
) ENGINE=InnoDB;
CREATE TABLE ORDERR (
    OrderID INTEGER,
    OrderDateTime DATETIME NOT NULL,
    ReturnDateTime DATETIME,
    PRIMARY KEY (OrderID),
    CHECK (ReturnDateTime IS NULL OR ReturnDateTime >= OrderDateTime)
) ENGINE=InnoDB;
CREATE TABLE PLACES (
    AccountNumber INTEGER NOT NULL,
    OrderID INTEGER,
    PRIMARY KEY (OrderID),
    FOREIGN KEY (AccountNumber) REFERENCES ACCOUNT(AccountNumber)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    FOREIGN KEY (OrderID) REFERENCES ORDERR(OrderID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;
CREATE TABLE ORDER_MOVIE (
    OrderID INTEGER,
    MovieID INTEGER NOT NULL,
    PRIMARY KEY (OrderID),
    FOREIGN KEY (OrderID) REFERENCES ORDERR(OrderID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (MovieID) REFERENCES MOVIE(MovieID)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
) ENGINE=InnoDB;
CREATE TABLE FEATURES (
    MovieID INTEGER,
    ActorID INTEGER,
    PRIMARY KEY (MovieID, ActorID),
    FOREIGN KEY (MovieID) REFERENCES MOVIE(MovieID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (ActorID) REFERENCES ACTOR(ActorID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;
CREATE TABLE HANDLEDBY (
    OrderID INTEGER,
    SocialSecurityNumber CHAR(11) NOT NULL,
    PRIMARY KEY (OrderID),
    FOREIGN KEY (OrderID) REFERENCES ORDERR(OrderID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (SocialSecurityNumber) REFERENCES EMPLOYEE(SocialSecurityNumber)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
) ENGINE=InnoDB;
CREATE TABLE QUEUES (
    AccountNumber INTEGER,
    MovieID INTEGER NOT NULL,
    QueuePosition INTEGER NOT NULL,
    PRIMARY KEY (AccountNumber, QueuePosition),
    UNIQUE (AccountNumber, MovieID),
    CHECK (QueuePosition > 0),
    FOREIGN KEY (AccountNumber) REFERENCES ACCOUNT(AccountNumber)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (MovieID) REFERENCES MOVIE(MovieID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;
CREATE TABLE RATES (
    AccountNumber INTEGER,
    MovieID INTEGER,
    Rating INTEGER NOT NULL,
    PRIMARY KEY (AccountNumber, MovieID),
    CHECK (Rating >= 1 AND Rating <= 5),
    FOREIGN KEY (AccountNumber) REFERENCES ACCOUNT(AccountNumber)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (MovieID) REFERENCES MOVIE(MovieID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

INSERT INTO PERSON VALUES
(1, 'Yang', 'Shang', '123 Success Street', 'Stony Brook', 'NY', '11790', '516-632-8959'),
(2, 'Du', 'Victor', '456 Fortune Road', 'Stony Brook', 'NY', '11790', '516-632-4360'),
(3, 'Smith', 'John', '789 Peace Blvd.', 'Los Angeles', 'CA', '93536', '315-443-4321'),
(4, 'Philip', 'Lewis', '135 Knowledge Lane', 'Stony Brook', 'NY', '11794', '516-666-8888'),
(5, 'Smith', 'David', '123 College road', 'Stony Brook', 'NY', '11790', '516-215-2345'),
(6, 'Warren', 'David', '456 Sunken Street', 'Stony Brook', 'NY', '11794', '631-632-9987');

INSERT INTO CUSTOMER VALUES
(1, '111-11-1111', 'syang@cs.sunysb.edu', '1234-5678-1234-5678', 1),
(2, '222-22-2222', 'vicdu@cs.sunysb.edu', '5678-1234-5678-1234', 1),
(3, '333-33-3333', 'jsmith@ic.sunysb.edu', '2345-6789-2345-6789', 1),
(4, '444-44-4444', 'pml@cs.sunysb.edu', '6789-2345-6789-2345', 1);

INSERT INTO EMPLOYEE VALUES
('123-45-6789', 5, '2005-11-01', 60, 'CustomerRepresentative'),
('789-12-3456', 6, '2006-02-02', 50, 'Manager');

INSERT INTO ACCOUNT VALUES
(1, '444-44-4444', 'Unlim2', '2006-10-01'),
(2, '222-22-2222', 'Lim', '2006-10-15');

INSERT INTO MOVIE VALUES
(1, 'The Godfather', 'Drama', 10000, 3, 5),
(2, 'Shawshank Redemption', 'Drama', 1000, 2, 4),
(3, 'Borat', 'Comedy', 500, 1, 3);

INSERT INTO ACTOR VALUES
(1, 'Al Pacino', 'M', 63, 5),
(2, 'Tim Robbins', 'M', 53, 2);

INSERT INTO FEATURES VALUES
(1, 1),
(3, 1),
(1, 2);

INSERT INTO ORDERR VALUES
(1, '2009-11-11 10:00:00', '2009-11-14 00:00:00'),
(2, '2009-11-11 18:15:00', '2009-11-11 18:15:00'),
(3, '2009-11-12 09:30:00', NULL),
(4, '2009-11-21 22:22:00', NULL);

INSERT INTO PLACES VALUES
(1, 1),
(2, 2),
(1, 3),
(2, 4);

INSERT INTO ORDER_MOVIE VALUES
(1, 1),
(2, 3),
(3, 3),
(4, 2);

INSERT INTO QUEUES VALUES
(1, 1, 1),
(1, 3, 2),
(2, 2, 1),
(2, 3, 2);

-- The official demo data does not assign representatives to the four orders.
-- For this test fixture only, assign all four to the sole demo representative,
-- David Smith. This is an explicit added assumption, not an official demo fact.
INSERT INTO HANDLEDBY (OrderID, SocialSecurityNumber) VALUES
(1, '123-45-6789'), (2, '123-45-6789'),
(3, '123-45-6789'), (4, '123-45-6789');

CREATE VIEW V_MOVIE_AVAILABILITY AS
SELECT m.MovieID, m.MovieName, m.MovieType, m.DistributionFee,
       m.NumberOfCopies, m.Rating,
       COALESCE(x.CopiesOut, 0) AS CopiesOut,
       CAST(m.NumberOfCopies AS SIGNED) - COALESCE(x.CopiesOut, 0) AS AvailableCopies
FROM MOVIE m
LEFT JOIN (
    SELECT om.MovieID, COUNT(*) AS CopiesOut
    FROM ORDER_MOVIE om JOIN ORDERR o ON o.OrderID = om.OrderID
    WHERE o.ReturnDateTime IS NULL
    GROUP BY om.MovieID
) x ON x.MovieID = m.MovieID;
