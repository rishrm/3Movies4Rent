-- Positive examples only. Run 01 and 02 in a NEW test database first.
-- These SQL examples have NOT been executed in this session.
USE `3Movies4Rent_A2_Test`;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- CRUD01 Add customer
START TRANSACTION;
INSERT INTO PERSON (PersonID, LastName, FirstName, Address, City, State, ZipCode, Telephone)
VALUES (7, 'Adams', 'John', '123 ABC Street', 'Stony Brook', 'NY', '11790', '631-000-0000');
INSERT INTO CUSTOMER (PersonID, CustomerID, EmailAddress, CreditCardNumber, Rating)
VALUES (7, '555-55-5555', 'JohnAdams@example.com', '1111-2222-3333-4444', 3);
SELECT P.PersonID, P.LastName, P.FirstName, P.Address, P.City, P.State, P.ZipCode, P.Telephone,
       C.CustomerID, C.EmailAddress, C.Rating
FROM PERSON P JOIN CUSTOMER C ON C.PersonID = P.PersonID
WHERE C.CustomerID = '555-55-5555'
ORDER BY C.CustomerID;
ROLLBACK;

-- CRUD02 Edit customer contact information
START TRANSACTION;
UPDATE PERSON P
JOIN CUSTOMER C ON C.PersonID = P.PersonID
SET P.Telephone = '631-000-0000'
WHERE C.CustomerID = '111-11-1111';
UPDATE CUSTOMER
SET EmailAddress = 'shang@example.com'
WHERE CustomerID = '111-11-1111';
SELECT P.PersonID, P.LastName, P.FirstName, P.Telephone, C.CustomerID, C.EmailAddress
FROM PERSON P JOIN CUSTOMER C ON C.PersonID = P.PersonID
WHERE C.CustomerID = '111-11-1111'
ORDER BY C.CustomerID;
ROLLBACK;

-- CRUD03 Add employee
START TRANSACTION;
INSERT INTO PERSON (PersonID, LastName, FirstName, Address, City, State, ZipCode, Telephone)
VALUES (7, 'Adams', 'Rachel', '123 ABC Street', 'Stony Brook', 'NY', '11790', '631-000-0000');
INSERT INTO EMPLOYEE (SocialSecurityNumber, PersonID, StartDate, HourlyRate, EmployeeType)
VALUES ('555-55-5555', 7, '2026-11-01', 25, 'Manager');
SELECT E.SocialSecurityNumber, P.PersonID, P.FirstName, P.LastName, P.Address, P.City,
       P.State, P.ZipCode, P.Telephone, E.StartDate, E.HourlyRate, E.EmployeeType
FROM EMPLOYEE E JOIN PERSON P ON P.PersonID = E.PersonID
WHERE E.SocialSecurityNumber = '555-55-5555'
ORDER BY E.SocialSecurityNumber;
ROLLBACK;

-- CRUD04 Edit employee hourly rate
START TRANSACTION;
UPDATE EMPLOYEE
SET HourlyRate = 55
WHERE SocialSecurityNumber = '789-12-3456';
SELECT E.SocialSecurityNumber, P.FirstName, P.LastName, E.StartDate, E.HourlyRate, E.EmployeeType
FROM EMPLOYEE E JOIN PERSON P ON P.PersonID = E.PersonID
WHERE E.SocialSecurityNumber = '789-12-3456'
ORDER BY E.SocialSecurityNumber;
ROLLBACK;

-- CRUD05 Add movie
START TRANSACTION;
INSERT INTO MOVIE (MovieID, MovieName, MovieType, DistributionFee, NumberOfCopies, Rating)
VALUES (4, 'Inception', 'Action', 2000, 5, 5);
SELECT MovieID, MovieName, MovieType, DistributionFee, NumberOfCopies, Rating
FROM MOVIE
WHERE MovieID = 4
ORDER BY MovieID;
ROLLBACK;

-- CRUD06 Delete movie
START TRANSACTION;
INSERT INTO MOVIE (MovieID, MovieName, MovieType, DistributionFee, NumberOfCopies, Rating)
VALUES (4, 'Inception', 'Action', 2000, 5, 5);
DELETE FROM MOVIE
WHERE MovieID = 4;
SELECT MovieID, MovieName, MovieType, DistributionFee, NumberOfCopies, Rating
FROM MOVIE
WHERE MovieID = 4
ORDER BY MovieID;
ROLLBACK;

-- CRUD07 Add actor
START TRANSACTION;
INSERT INTO ACTOR (ActorID, ActorName, Gender, Age, Rating)
VALUES (3, 'New Actor', 'M', 40, 3);
SELECT ActorID, ActorName, Gender, Age, Rating
FROM ACTOR
WHERE ActorID = 3
ORDER BY ActorID;
ROLLBACK;

-- CRUD08 Edit actor
START TRANSACTION;
UPDATE ACTOR
SET Age = 64, Rating = 4
WHERE ActorID = 1;
SELECT ActorID, ActorName, Gender, Age, Rating
FROM ACTOR
WHERE ActorID = 1
ORDER BY ActorID;
ROLLBACK;

-- CRUD09 Delete actor
START TRANSACTION;
INSERT INTO ACTOR (ActorID, ActorName, Gender, Age, Rating)
VALUES (3, 'New Actor', 'M', 40, 3);
DELETE FROM ACTOR
WHERE ActorID = 3;
SELECT ActorID, ActorName, Gender, Age, Rating
FROM ACTOR
WHERE ActorID = 3
ORDER BY ActorID;
ROLLBACK;

-- CRUD10 Add actor to movie
START TRANSACTION;
INSERT INTO FEATURES (MovieID, ActorID)
VALUES (2, 2);
SELECT F.MovieID, M.MovieName, F.ActorID, A.ActorName
FROM FEATURES F
JOIN MOVIE M ON M.MovieID = F.MovieID
JOIN ACTOR A ON A.ActorID = F.ActorID
WHERE F.MovieID = 2
ORDER BY F.MovieID, F.ActorID;
ROLLBACK;

-- CRUD11 Remove actor from movie
START TRANSACTION;
DELETE FROM FEATURES
WHERE MovieID = 1 AND ActorID = 2;
SELECT F.MovieID, M.MovieName, F.ActorID, A.ActorName
FROM FEATURES F
JOIN MOVIE M ON M.MovieID = F.MovieID
JOIN ACTOR A ON A.ActorID = F.ActorID
WHERE F.MovieID = 1
ORDER BY F.MovieID, F.ActorID;
ROLLBACK;

-- R01 Monthly subscription income estimate
START TRANSACTION;
WITH report_parameters AS (
    SELECT CAST('2009-11-01' AS DATE) AS MonthStart
)
SELECT rp.MonthStart AS ReportMonth,
       COUNT(a.AccountNumber) AS AssumedActiveSubscriptions,
       CAST(COALESCE(SUM(
           CASE a.AccountType
               WHEN 'Lim' THEN 10.00
               WHEN 'Unlim1' THEN 15.00
               WHEN 'Unlim2' THEN 20.00
               WHEN 'Unlim3' THEN 25.00
               ELSE 0.00
           END
       ), 0.00) AS DECIMAL(12,2)) AS EstimatedMonthlyIncome
FROM report_parameters rp
LEFT JOIN ACCOUNT a
    ON a.AccountCreationDate < DATE_ADD(rp.MonthStart, INTERVAL 1 MONTH)
GROUP BY rp.MonthStart;
ROLLBACK;

-- R02 Comprehensive movie listing
START TRANSACTION;
SELECT v.MovieID, v.MovieName, v.MovieType, v.DistributionFee,
       v.NumberOfCopies, v.Rating, v.CopiesOut, v.AvailableCopies,
       GROUP_CONCAT(a.ActorName ORDER BY a.ActorName, a.ActorID SEPARATOR ', ') AS Actors
FROM V_MOVIE_AVAILABILITY v
LEFT JOIN FEATURES f ON f.MovieID = v.MovieID
LEFT JOIN ACTOR a ON a.ActorID = f.ActorID
GROUP BY v.MovieID, v.MovieName, v.MovieType, v.DistributionFee,
         v.NumberOfCopies, v.Rating, v.CopiesOut, v.AvailableCopies
ORDER BY v.MovieID;
ROLLBACK;

-- R03 Rental history by movie name
START TRANSACTION;
SELECT o.OrderID, m.MovieID, m.MovieName, m.MovieType,
       ac.AccountNumber, ac.CustomerID,
       o.OrderDateTime, o.ReturnDateTime
FROM MOVIE m
JOIN ORDER_MOVIE om ON om.MovieID = m.MovieID
JOIN ORDERR o ON o.OrderID = om.OrderID
JOIN PLACES pl ON pl.OrderID = o.OrderID
JOIN ACCOUNT ac ON ac.AccountNumber = pl.AccountNumber
WHERE m.MovieName = 'Borat'
ORDER BY o.OrderDateTime, o.OrderID;
ROLLBACK;

-- R04 Rental history by movie type
START TRANSACTION;
SELECT o.OrderID, m.MovieID, m.MovieName, m.MovieType,
       ac.AccountNumber, ac.CustomerID,
       o.OrderDateTime, o.ReturnDateTime
FROM MOVIE m
JOIN ORDER_MOVIE om ON om.MovieID = m.MovieID
JOIN ORDERR o ON o.OrderID = om.OrderID
JOIN PLACES pl ON pl.OrderID = o.OrderID
JOIN ACCOUNT ac ON ac.AccountNumber = pl.AccountNumber
WHERE m.MovieType = 'Drama'
ORDER BY o.OrderDateTime, o.OrderID;
ROLLBACK;

-- R05 Rental history by customer name
START TRANSACTION;
SELECT c.CustomerID, p.FirstName, p.LastName,
       ac.AccountNumber, o.OrderID, m.MovieID, m.MovieName,
       o.OrderDateTime, o.ReturnDateTime
FROM PERSON p
JOIN CUSTOMER c ON c.PersonID = p.PersonID
JOIN ACCOUNT ac ON ac.CustomerID = c.CustomerID
JOIN PLACES pl ON pl.AccountNumber = ac.AccountNumber
JOIN ORDERR o ON o.OrderID = pl.OrderID
JOIN ORDER_MOVIE om ON om.OrderID = o.OrderID
JOIN MOVIE m ON m.MovieID = om.MovieID
WHERE p.FirstName = 'Lewis' AND p.LastName = 'Philip'
ORDER BY c.CustomerID, o.OrderDateTime, o.OrderID;
ROLLBACK;

-- R06 Customer representatives who handled the most rentals
START TRANSACTION;
WITH representative_counts AS (
    SELECT e.SocialSecurityNumber, p.FirstName, p.LastName,
           COUNT(om.OrderID) AS OrdersHandled
    FROM EMPLOYEE e
    JOIN PERSON p ON p.PersonID = e.PersonID
    LEFT JOIN HANDLEDBY h ON h.SocialSecurityNumber = e.SocialSecurityNumber
    LEFT JOIN ORDERR o ON o.OrderID = h.OrderID
    LEFT JOIN ORDER_MOVIE om ON om.OrderID = o.OrderID
    WHERE e.EmployeeType = 'CustomerRepresentative'
    GROUP BY e.SocialSecurityNumber, p.FirstName, p.LastName
)
SELECT SocialSecurityNumber, FirstName, LastName, OrdersHandled
FROM representative_counts
WHERE OrdersHandled > 0
  AND OrdersHandled = (SELECT MAX(OrdersHandled) FROM representative_counts)
ORDER BY SocialSecurityNumber;
ROLLBACK;

-- R07 Most active customers, including all first-place ties
START TRANSACTION;
WITH rental_counts AS (
    SELECT ac.CustomerID, COUNT(om.OrderID) AS TotalRentals
    FROM ACCOUNT ac
    JOIN PLACES pl ON pl.AccountNumber = ac.AccountNumber
    JOIN ORDERR o ON o.OrderID = pl.OrderID
    JOIN ORDER_MOVIE om ON om.OrderID = o.OrderID
    GROUP BY ac.CustomerID
)
SELECT c.CustomerID, p.FirstName, p.LastName, rc.TotalRentals
FROM rental_counts rc
JOIN CUSTOMER c ON c.CustomerID = rc.CustomerID
JOIN PERSON p ON p.PersonID = c.PersonID
WHERE rc.TotalRentals > 0
  AND rc.TotalRentals = (SELECT MAX(TotalRentals) FROM rental_counts)
ORDER BY c.CustomerID;
ROLLBACK;

-- R08 Most actively rented movies / customer best-seller list
START TRANSACTION;
WITH movie_counts AS (
    SELECT m.MovieID, m.MovieName, m.MovieType,
           COUNT(o.OrderID) AS RentalCount
    FROM MOVIE m
    LEFT JOIN ORDER_MOVIE om ON om.MovieID = m.MovieID
    LEFT JOIN ORDERR o ON o.OrderID = om.OrderID
    GROUP BY m.MovieID, m.MovieName, m.MovieType
)
SELECT MovieID, MovieName, MovieType, RentalCount,
       DENSE_RANK() OVER (ORDER BY RentalCount DESC) AS PopularityRank
FROM movie_counts
ORDER BY RentalCount DESC, MovieID;
ROLLBACK;

-- R09 Customer mailing list
START TRANSACTION;
SELECT c.CustomerID, p.FirstName, p.LastName,
       p.Address, p.City, p.State, p.ZipCode, c.EmailAddress
FROM CUSTOMER c
JOIN PERSON p ON p.PersonID = c.PersonID
ORDER BY p.LastName, p.FirstName, c.CustomerID;
ROLLBACK;

-- R10 Nearest-neighbor movie suggestions
START TRANSACTION;
WITH target_customer AS (
    SELECT CustomerID
    FROM CUSTOMER
    WHERE CustomerID = '444-44-4444'
),
rental_history AS (
    SELECT DISTINCT ac.CustomerID, om.MovieID
    FROM ACCOUNT ac
    JOIN PLACES pl ON pl.AccountNumber = ac.AccountNumber
    JOIN ORDERR o ON o.OrderID = pl.OrderID
    JOIN ORDER_MOVIE om ON om.OrderID = o.OrderID
),
overlap_scores AS (
    SELECT other.CustomerID, COUNT(*) AS SharedTitles
    FROM target_customer target
    JOIN rental_history own ON own.CustomerID = target.CustomerID
    JOIN rental_history other
      ON other.MovieID = own.MovieID
     AND other.CustomerID <> target.CustomerID
    GROUP BY other.CustomerID
),
nearest_neighbors AS (
    SELECT CustomerID, SharedTitles
    FROM overlap_scores
    WHERE SharedTitles = (SELECT MAX(SharedTitles) FROM overlap_scores)
)
SELECT m.MovieID, m.MovieName, m.MovieType,
       COUNT(DISTINCT neighbor.CustomerID) AS RecommendingNeighbors,
       MAX(neighbor.SharedTitles) AS NearestNeighborSharedTitles
FROM nearest_neighbors neighbor
JOIN rental_history candidate ON candidate.CustomerID = neighbor.CustomerID
JOIN MOVIE m ON m.MovieID = candidate.MovieID
WHERE NOT EXISTS (
    SELECT 1
    FROM rental_history prior_rental
    JOIN target_customer target ON target.CustomerID = prior_rental.CustomerID
    WHERE prior_rental.MovieID = m.MovieID
)
GROUP BY m.MovieID, m.MovieName, m.MovieType
ORDER BY RecommendingNeighbors DESC, m.MovieID;
ROLLBACK;

-- R11 Customer's currently held movies
START TRANSACTION;
SELECT m.MovieID, m.MovieName, m.MovieType,
       o.OrderID, o.OrderDateTime
FROM ACCOUNT ac
JOIN PLACES pl ON pl.AccountNumber = ac.AccountNumber
JOIN ORDERR o ON o.OrderID = pl.OrderID
JOIN ORDER_MOVIE om ON om.OrderID = o.OrderID
JOIN MOVIE m ON m.MovieID = om.MovieID
WHERE ac.AccountNumber = 1
  AND ac.CustomerID = '444-44-4444'
  AND o.ReturnDateTime IS NULL
ORDER BY o.OrderDateTime, o.OrderID;
ROLLBACK;

-- R12 Customer's movie queue
START TRANSACTION;
SELECT q.QueuePosition, m.MovieID, m.MovieName, m.MovieType
FROM ACCOUNT ac
JOIN QUEUES q ON q.AccountNumber = ac.AccountNumber
JOIN MOVIE m ON m.MovieID = q.MovieID
WHERE ac.AccountNumber = 1
  AND ac.CustomerID = '444-44-4444'
ORDER BY q.QueuePosition;
ROLLBACK;

-- R13 Customer's account settings
START TRANSACTION;
SELECT ac.AccountNumber, ac.CustomerID, ac.AccountType, ac.AccountCreationDate,
       CASE ac.AccountType
           WHEN 'Lim' THEN 10.00
           WHEN 'Unlim1' THEN 15.00
           WHEN 'Unlim2' THEN 20.00
           WHEN 'Unlim3' THEN 25.00
       END AS MonthlyFee,
       p.FirstName, p.LastName, p.Address, p.City, p.State,
       p.ZipCode, p.Telephone, c.EmailAddress,
       CONCAT('****-****-****-', RIGHT(c.CreditCardNumber, 4)) AS MaskedCreditCardNumber
FROM ACCOUNT ac
JOIN CUSTOMER c ON c.CustomerID = ac.CustomerID
JOIN PERSON p ON p.PersonID = c.PersonID
WHERE ac.AccountNumber = 1
  AND ac.CustomerID = '444-44-4444';
ROLLBACK;

-- R14 Customer's current and past order history
START TRANSACTION;
SELECT o.OrderID, o.OrderDateTime, o.ReturnDateTime,
       m.MovieID, m.MovieName, m.MovieType,
       CASE WHEN o.ReturnDateTime IS NULL THEN 'Currently held' ELSE 'Returned' END AS RentalStatus
FROM ACCOUNT ac
JOIN PLACES pl ON pl.AccountNumber = ac.AccountNumber
JOIN ORDERR o ON o.OrderID = pl.OrderID
JOIN ORDER_MOVIE om ON om.OrderID = o.OrderID
JOIN MOVIE m ON m.MovieID = om.MovieID
WHERE ac.AccountNumber = 1
  AND ac.CustomerID = '444-44-4444'
ORDER BY o.OrderDateTime, o.OrderID;
ROLLBACK;

-- R15 Available movies by type
START TRANSACTION;
SELECT MovieID, MovieName, MovieType, Rating, AvailableCopies
FROM V_MOVIE_AVAILABILITY
WHERE MovieType = 'Drama'
  AND AvailableCopies > 0
ORDER BY MovieName, MovieID;
ROLLBACK;

-- R16 Available movies by one literal title keyword
START TRANSACTION;
SELECT MovieID, MovieName, MovieType, Rating, AvailableCopies
FROM V_MOVIE_AVAILABILITY
WHERE AvailableCopies > 0
  AND LOCATE('Godfather', MovieName) > 0
ORDER BY MovieName, MovieID;
ROLLBACK;

-- R17 Available movies containing all requested title keywords
START TRANSACTION;
SELECT MovieID, MovieName, MovieType, Rating, AvailableCopies
FROM V_MOVIE_AVAILABILITY
WHERE AvailableCopies > 0
  AND LOCATE('The', MovieName) > 0
  AND LOCATE('Godfather', MovieName) > 0
ORDER BY MovieName, MovieID;
ROLLBACK;

-- R18 Available movies starring a selected actor
START TRANSACTION;
SELECT v.MovieID, v.MovieName, v.MovieType, v.Rating, v.AvailableCopies
FROM V_MOVIE_AVAILABILITY v
WHERE v.AvailableCopies > 0
  AND EXISTS (
      SELECT 1
      FROM FEATURES f
      WHERE f.MovieID = v.MovieID AND f.ActorID = 1
  )
ORDER BY v.MovieName, v.MovieID;
ROLLBACK;

-- R19 Available movies starring all selected actors
START TRANSACTION;
SELECT v.MovieID, v.MovieName, v.MovieType, v.Rating, v.AvailableCopies
FROM V_MOVIE_AVAILABILITY v
WHERE v.AvailableCopies > 0
  AND EXISTS (
      SELECT 1
      FROM FEATURES f1
      WHERE f1.MovieID = v.MovieID AND f1.ActorID = 1
  )
  AND EXISTS (
      SELECT 1
      FROM FEATURES f2
      WHERE f2.MovieID = v.MovieID AND f2.ActorID = 2
  )
ORDER BY v.MovieName, v.MovieID;
ROLLBACK;

-- R20 Employee information visible to customer representatives
START TRANSACTION;
SELECT e.SocialSecurityNumber, e.PersonID,
       p.FirstName, p.LastName, p.Address, p.City, p.State,
       p.ZipCode, p.Telephone, e.StartDate, e.EmployeeType
FROM EMPLOYEE e
JOIN PERSON p ON p.PersonID = e.PersonID
ORDER BY p.LastName, p.FirstName, e.SocialSecurityNumber;
ROLLBACK;

-- P01 Record a rental / customer places an order
START TRANSACTION;
CALL rent_movie(5, 1, '444-44-4444', 1, '123-45-6789', '2009-11-22 10:00:00');
SELECT o.OrderID, p.AccountNumber, om.MovieID, h.SocialSecurityNumber, o.OrderDateTime, o.ReturnDateTime FROM ORDERR o JOIN PLACES p USING (OrderID) JOIN ORDER_MOVIE om USING (OrderID) JOIN HANDLEDBY h USING (OrderID) WHERE o.OrderID = 5;
SELECT * FROM QUEUES WHERE AccountNumber = 1 ORDER BY QueuePosition;
ROLLBACK;

-- P02 Return a movie and offer the next available queued movie
START TRANSACTION;
CALL return_movie(3, 1, '444-44-4444', '2009-11-22 10:00:00');
CALL fulfill_next(5, 1, '444-44-4444', '123-45-6789', '2009-11-22 10:00:00');
SELECT * FROM ORDERR WHERE OrderID IN (3, 5) ORDER BY OrderID;
SELECT o.OrderID, p.AccountNumber, om.MovieID, h.SocialSecurityNumber, o.OrderDateTime, o.ReturnDateTime FROM ORDERR o JOIN PLACES p USING (OrderID) JOIN ORDER_MOVIE om USING (OrderID) JOIN HANDLEDBY h USING (OrderID) WHERE o.OrderID = 5;
SELECT * FROM QUEUES WHERE AccountNumber = 1 ORDER BY QueuePosition;
ROLLBACK;

-- P03 Add a movie to the queue
START TRANSACTION;
CALL queue_add(1, '444-44-4444', 2);
SELECT * FROM QUEUES WHERE AccountNumber = 1 ORDER BY QueuePosition;
ROLLBACK;

-- P04 Remove a queued movie
START TRANSACTION;
CALL queue_remove(1, '444-44-4444', 1);
SELECT * FROM QUEUES WHERE AccountNumber = 1 ORDER BY QueuePosition;
ROLLBACK;

-- P05 Reorder the movie queue
START TRANSACTION;
CALL queue_move(1, '444-44-4444', 2, 1);
SELECT * FROM QUEUES WHERE AccountNumber = 1 ORDER BY QueuePosition;
ROLLBACK;

-- P06 Rate a previously rented movie
START TRANSACTION;
CALL rate_movie(1, '444-44-4444', 1, 5);
SELECT * FROM RATES WHERE AccountNumber = 1 AND MovieID = 1;
ROLLBACK;

-- P07 Update an existing movie rating
START TRANSACTION;
CALL rate_movie(1, '444-44-4444', 1, 5);
CALL rate_movie(1, '444-44-4444', 1, 4);
SELECT * FROM RATES WHERE AccountNumber = 1 AND MovieID = 1;
ROLLBACK;

-- P08 Delete an unreferenced customer
START TRANSACTION;
CALL delete_customer('111-11-1111');
SELECT * FROM CUSTOMER WHERE CustomerID = '111-11-1111';
SELECT * FROM PERSON WHERE PersonID = 1;
ROLLBACK;

-- P09 Delete an unreferenced employee
START TRANSACTION;
CALL delete_employee('789-12-3456');
SELECT * FROM EMPLOYEE WHERE SocialSecurityNumber = '789-12-3456';
SELECT * FROM PERSON WHERE PersonID = 6;
ROLLBACK;

-- P10 Edit movie information without invalidating circulation
START TRANSACTION;
CALL edit_movie(1, 'The Godfather Updated', 'Drama', 12000, 5, 4);
SELECT * FROM MOVIE WHERE MovieID = 1;
ROLLBACK;

-- P11 Enroll an existing customer in a rental plan
START TRANSACTION;
INSERT INTO ACCOUNT (AccountNumber, CustomerID, AccountType, AccountCreationDate) VALUES (3, '111-11-1111', 'Unlim1', '2009-11-22');
SELECT * FROM ACCOUNT WHERE AccountNumber = 3;
ROLLBACK;

-- E01 Return succeeds when monthly quota prevents the next rental
START TRANSACTION;
CALL return_movie(4, 2, '222-22-2222', '2009-11-22 10:00:00');
CALL fulfill_next(5, 2, '222-22-2222', '123-45-6789', '2009-11-22 10:00:00');
SELECT OrderID, ReturnDateTime FROM ORDERR WHERE OrderID = 4;
SELECT COUNT(*) AS NewOrderCount FROM ORDERR WHERE OrderID = 5;
ROLLBACK;

-- E02 Next available movie skips an unavailable first queue item
START TRANSACTION;
CALL queue_move(1, '444-44-4444', 2, 1);
CALL fulfill_next(5, 1, '444-44-4444', '123-45-6789', '2009-11-22 10:00:00');
SELECT o.OrderID, p.AccountNumber, om.MovieID, h.SocialSecurityNumber, o.OrderDateTime, o.ReturnDateTime FROM ORDERR o JOIN PLACES p USING (OrderID) JOIN ORDER_MOVIE om USING (OrderID) JOIN HANDLEDBY h USING (OrderID) WHERE o.OrderID = 5;
SELECT * FROM QUEUES WHERE AccountNumber = 1 ORDER BY QueuePosition;
ROLLBACK;

-- E03 Limited-plan quota resets in the next calendar month
START TRANSACTION;
CALL return_movie(4, 2, '222-22-2222', '2009-11-22 10:00:00');
CALL rent_movie(5, 2, '222-22-2222', 1, '123-45-6789', '2009-12-01 10:00:00');
SELECT o.OrderID, p.AccountNumber, om.MovieID, h.SocialSecurityNumber, o.OrderDateTime, o.ReturnDateTime FROM ORDERR o JOIN PLACES p USING (OrderID) JOIN ORDER_MOVIE om USING (OrderID) JOIN HANDLEDBY h USING (OrderID) WHERE o.OrderID = 5;
ROLLBACK;
