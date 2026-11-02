-- Call every mutation in a READ COMMITTED transaction.
-- Successful calls are committed by the caller. Errors roll back the transaction.
-- CustomerID arguments must come from the authenticated application session.
DELIMITER $$

CREATE PROCEDURE assert_account(IN p_account INT, IN p_customer CHAR(11))
BEGIN
    DECLARE v_customer CHAR(11) DEFAULT NULL;
    SELECT CustomerID INTO v_customer FROM ACCOUNT
    WHERE AccountNumber = p_account FOR UPDATE;
    IF v_customer IS NULL OR p_customer IS NULL OR v_customer <> p_customer THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found or not owned by this customer';
    END IF;
END$$

CREATE PROCEDURE rent_movie(IN p_order INT, IN p_account INT,
    IN p_customer CHAR(11), IN p_movie INT, IN p_rep CHAR(11), IN p_when DATETIME)
BEGIN
    DECLARE v_plan CHAR(11);
    DECLARE v_created DATE;
    DECLARE v_role CHAR(25) DEFAULT NULL;
    DECLARE v_copies INT DEFAULT NULL;
    DECLARE v_open INT;
    DECLARE v_month INT;
    DECLARE v_limit INT;
    DECLARE v_position INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    SELECT AccountType, AccountCreationDate INTO v_plan, v_created
    FROM ACCOUNT WHERE AccountNumber = p_account;
    IF p_when IS NULL OR p_when < v_created THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rental date precedes account creation or is null';
    END IF;
    SELECT EmployeeType INTO v_role FROM EMPLOYEE
    WHERE SocialSecurityNumber = p_rep FOR SHARE;
    IF v_role IS NULL OR v_role <> 'CustomerRepresentative' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A customer representative must handle the rental';
    END IF;
    SELECT NumberOfCopies INTO v_copies FROM MOVIE WHERE MovieID = p_movie FOR UPDATE;
    IF v_copies IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movie not found';
    END IF;
    SELECT COUNT(*) INTO v_open FROM PLACES p JOIN ORDERR o USING (OrderID)
    WHERE p.AccountNumber = p_account AND o.ReturnDateTime IS NULL;
    SET v_limit = CASE v_plan WHEN 'Unlim2' THEN 2 WHEN 'Unlim3' THEN 3 ELSE 1 END;
    IF v_open >= v_limit THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Concurrent rental limit reached';
    END IF;
    SELECT COUNT(*) INTO v_month FROM PLACES p JOIN ORDERR o USING (OrderID)
    WHERE p.AccountNumber = p_account
      AND o.OrderDateTime >= CAST(DATE_FORMAT(p_when, '%Y-%m-01') AS DATE)
      AND o.OrderDateTime < DATE_ADD(CAST(DATE_FORMAT(p_when, '%Y-%m-01') AS DATE), INTERVAL 1 MONTH);
    IF v_plan = 'Lim' AND v_month >= 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Limited plan monthly quota reached';
    END IF;
    SELECT COUNT(*) INTO v_open FROM ORDER_MOVIE om JOIN ORDERR o USING (OrderID)
    WHERE om.MovieID = p_movie AND o.ReturnDateTime IS NULL;
    IF v_open >= v_copies THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No copy of this movie is available';
    END IF;
    IF EXISTS (SELECT 1 FROM PLACES p JOIN ORDERR o USING (OrderID)
        JOIN ORDER_MOVIE om USING (OrderID)
        WHERE p.AccountNumber = p_account AND om.MovieID = p_movie AND o.ReturnDateTime IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This account already holds the movie';
    END IF;
    INSERT INTO ORDERR (OrderID, OrderDateTime, ReturnDateTime) VALUES (p_order, p_when, NULL);
    INSERT INTO PLACES (AccountNumber, OrderID) VALUES (p_account, p_order);
    INSERT INTO ORDER_MOVIE (OrderID, MovieID) VALUES (p_order, p_movie);
    INSERT INTO HANDLEDBY (OrderID, SocialSecurityNumber) VALUES (p_order, p_rep);
    SELECT MIN(QueuePosition) INTO v_position FROM QUEUES
    WHERE AccountNumber = p_account AND MovieID = p_movie;
    IF v_position IS NOT NULL THEN
        DELETE FROM QUEUES WHERE AccountNumber = p_account AND QueuePosition = v_position;
        UPDATE QUEUES SET QueuePosition = QueuePosition - 1
        WHERE AccountNumber = p_account AND QueuePosition > v_position ORDER BY QueuePosition;
    END IF;
END$$

CREATE PROCEDURE return_movie(IN p_order INT, IN p_account INT,
    IN p_customer CHAR(11), IN p_when DATETIME)
BEGIN
    DECLARE v_movie INT DEFAULT NULL;
    DECLARE v_started DATETIME;
    DECLARE v_returned DATETIME;
    DECLARE v_dummy INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    SELECT om.MovieID, o.OrderDateTime, o.ReturnDateTime
    INTO v_movie, v_started, v_returned
    FROM ORDERR o JOIN PLACES p USING (OrderID) JOIN ORDER_MOVIE om USING (OrderID)
    WHERE o.OrderID = p_order AND p.AccountNumber = p_account FOR UPDATE;
    IF v_movie IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rental not found for this account';
    END IF;
    IF v_returned IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movie has already been returned';
    END IF;
    IF p_when IS NULL OR p_when < v_started THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return date must not precede rental date';
    END IF;
    SELECT NumberOfCopies INTO v_dummy FROM MOVIE WHERE MovieID = v_movie FOR UPDATE;
    UPDATE ORDERR SET ReturnDateTime = p_when WHERE OrderID = p_order;
END$$

CREATE PROCEDURE queue_add(IN p_account INT, IN p_customer CHAR(11), IN p_movie INT)
BEGIN
    DECLARE v_position INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    IF NOT EXISTS (SELECT 1 FROM MOVIE WHERE MovieID = p_movie) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movie not found';
    END IF;
    IF EXISTS (SELECT 1 FROM QUEUES WHERE AccountNumber = p_account AND MovieID = p_movie) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movie is already queued';
    END IF;
    SELECT COALESCE(MAX(QueuePosition), 0) + 1 INTO v_position
    FROM QUEUES WHERE AccountNumber = p_account;
    INSERT INTO QUEUES (AccountNumber, MovieID, QueuePosition) VALUES (p_account, p_movie, v_position);
END$$

CREATE PROCEDURE queue_remove(IN p_account INT, IN p_customer CHAR(11), IN p_position INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    DELETE FROM QUEUES WHERE AccountNumber = p_account AND QueuePosition = p_position;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Queue position not found';
    END IF;
    UPDATE QUEUES SET QueuePosition = QueuePosition - 1
    WHERE AccountNumber = p_account AND QueuePosition > p_position ORDER BY QueuePosition;
END$$

CREATE PROCEDURE queue_move(IN p_account INT, IN p_customer CHAR(11), IN p_old INT, IN p_new INT)
BEGIN
    DECLARE v_max INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    SELECT MAX(QueuePosition) INTO v_max FROM QUEUES WHERE AccountNumber = p_account;
    IF p_old IS NULL OR p_new IS NULL OR v_max IS NULL OR p_old < 1 OR p_new < 1
        OR p_old > v_max OR p_new > v_max
        OR NOT EXISTS (SELECT 1 FROM QUEUES WHERE AccountNumber = p_account AND QueuePosition = p_old) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid queue position';
    END IF;
    UPDATE QUEUES SET QueuePosition = v_max + 1
    WHERE AccountNumber = p_account AND QueuePosition = p_old;
    IF p_new < p_old THEN
        UPDATE QUEUES SET QueuePosition = QueuePosition + 1
        WHERE AccountNumber = p_account AND QueuePosition >= p_new AND QueuePosition < p_old
        ORDER BY QueuePosition DESC;
    ELSEIF p_new > p_old THEN
        UPDATE QUEUES SET QueuePosition = QueuePosition - 1
        WHERE AccountNumber = p_account AND QueuePosition > p_old AND QueuePosition <= p_new
        ORDER BY QueuePosition;
    END IF;
    UPDATE QUEUES SET QueuePosition = p_new
    WHERE AccountNumber = p_account AND QueuePosition = v_max + 1;
END$$

CREATE PROCEDURE fulfill_next(IN p_order INT, IN p_account INT, IN p_customer CHAR(11),
    IN p_rep CHAR(11), IN p_when DATETIME)
BEGIN
    DECLARE v_movie INT DEFAULT NULL;
    DECLARE v_plan CHAR(11);
    DECLARE v_limit INT;
    DECLARE v_open INT;
    DECLARE v_month INT;
    DECLARE v_copies INT;
    DECLARE v_last_position INT DEFAULT 0;
    DECLARE v_position INT;
    DECLARE v_done BOOL DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    SELECT AccountType INTO v_plan FROM ACCOUNT WHERE AccountNumber = p_account;
    SET v_limit = CASE v_plan WHEN 'Unlim2' THEN 2 WHEN 'Unlim3' THEN 3 ELSE 1 END;
    SELECT COUNT(*) INTO v_open FROM PLACES p JOIN ORDERR o USING (OrderID)
    WHERE p.AccountNumber = p_account AND o.ReturnDateTime IS NULL;
    SELECT COUNT(*) INTO v_month FROM PLACES p JOIN ORDERR o USING (OrderID)
    WHERE p.AccountNumber = p_account
      AND o.OrderDateTime >= CAST(DATE_FORMAT(p_when, '%Y-%m-01') AS DATE)
      AND o.OrderDateTime < DATE_ADD(CAST(DATE_FORMAT(p_when, '%Y-%m-01') AS DATE), INTERVAL 1 MONTH);
    IF v_open < v_limit AND (v_plan <> 'Lim' OR v_month < 2) THEN
        candidates: LOOP
            SELECT MIN(QueuePosition) INTO v_position FROM QUEUES
            WHERE AccountNumber = p_account AND QueuePosition > v_last_position;
            IF v_position IS NULL THEN LEAVE candidates; END IF;
            SELECT MovieID INTO v_movie FROM QUEUES
            WHERE AccountNumber = p_account AND QueuePosition = v_position;
            SELECT NumberOfCopies INTO v_copies FROM MOVIE WHERE MovieID = v_movie FOR UPDATE;
            SELECT COUNT(*) INTO v_open FROM ORDER_MOVIE om JOIN ORDERR o USING (OrderID)
            WHERE om.MovieID = v_movie AND o.ReturnDateTime IS NULL;
            IF v_open < v_copies AND NOT EXISTS (
                SELECT 1 FROM PLACES p JOIN ORDERR o USING (OrderID) JOIN ORDER_MOVIE om USING (OrderID)
                WHERE p.AccountNumber = p_account AND om.MovieID = v_movie AND o.ReturnDateTime IS NULL
            ) THEN
                CALL rent_movie(p_order, p_account, p_customer, v_movie, p_rep, p_when);
                SET v_done = TRUE;
                LEAVE candidates;
            END IF;
            SET v_last_position = v_position;
        END LOOP;
    END IF;
    SELECT IF(v_done, 'rented', 'waiting') AS FulfillmentStatus,
           IF(v_done, p_order, NULL) AS NewOrderID, IF(v_done, v_movie, NULL) AS MovieID;
END$$

CREATE PROCEDURE rate_movie(IN p_account INT, IN p_customer CHAR(11), IN p_movie INT, IN p_rating INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    CALL assert_account(p_account, p_customer);
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rating must be from 1 to 5';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PLACES p JOIN ORDER_MOVIE om USING (OrderID)
        WHERE p.AccountNumber = p_account AND om.MovieID = p_movie) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only a movie rented by this account can be rated';
    END IF;
    IF EXISTS (SELECT 1 FROM RATES WHERE AccountNumber = p_account AND MovieID = p_movie) THEN
        UPDATE RATES SET Rating = p_rating WHERE AccountNumber = p_account AND MovieID = p_movie;
    ELSE
        INSERT INTO RATES (AccountNumber, MovieID, Rating) VALUES (p_account, p_movie, p_rating);
    END IF;
END$$

CREATE PROCEDURE delete_customer(IN p_customer CHAR(11))
BEGIN
    DECLARE v_person INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    SELECT PersonID INTO v_person FROM CUSTOMER WHERE CustomerID = p_customer FOR UPDATE;
    IF v_person IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer not found'; END IF;
    -- Existing rental history is protected by PLACES -> ACCOUNT NO ACTION.
    -- Any failed delete rolls back the entire operation; no associations are removed.
    DELETE FROM ACCOUNT WHERE CustomerID = p_customer;
    DELETE FROM CUSTOMER WHERE CustomerID = p_customer;
    DELETE FROM PERSON WHERE PersonID = v_person
      AND NOT EXISTS (SELECT 1 FROM EMPLOYEE WHERE PersonID = v_person);
END$$

CREATE PROCEDURE delete_employee(IN p_employee CHAR(11))
BEGIN
    DECLARE v_person INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    SELECT PersonID INTO v_person FROM EMPLOYEE WHERE SocialSecurityNumber = p_employee FOR UPDATE;
    IF v_person IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Employee not found'; END IF;
    -- HANDLEDBY prevents deleting an employee referenced by rental history.
    DELETE FROM EMPLOYEE WHERE SocialSecurityNumber = p_employee;
    DELETE FROM PERSON WHERE PersonID = v_person
      AND NOT EXISTS (SELECT 1 FROM CUSTOMER WHERE PersonID = v_person);
END$$

CREATE PROCEDURE edit_movie(IN p_movie INT, IN p_name CHAR(100), IN p_type CHAR(10),
    IN p_fee DECIMAL(10,2), IN p_copies INT, IN p_rating INT)
BEGIN
    DECLARE v_existing INT DEFAULT NULL;
    DECLARE v_open INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    SELECT NumberOfCopies INTO v_existing FROM MOVIE WHERE MovieID = p_movie FOR UPDATE;
    IF v_existing IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movie not found'; END IF;
    SELECT COUNT(*) INTO v_open FROM ORDER_MOVIE om JOIN ORDERR o USING (OrderID)
    WHERE om.MovieID = p_movie AND o.ReturnDateTime IS NULL;
    IF p_copies IS NULL OR p_copies < v_open THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Copies cannot be less than outstanding rentals';
    END IF;
    UPDATE MOVIE SET MovieName = p_name, MovieType = p_type, DistributionFee = p_fee,
        NumberOfCopies = p_copies, Rating = p_rating WHERE MovieID = p_movie;
END$$
DELIMITER ;
