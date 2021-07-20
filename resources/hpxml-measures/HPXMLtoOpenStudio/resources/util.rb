# frozen_string_literal: true

class MathTools
  def self.valid_float?(str)
    !!Float(str) rescue false
  end

  def self.interp2(x, x0, x1, f0, f1)
    '''
    Returns the linear interpolation between two results.
    '''

    return f0 + ((x - x0) / (x1 - x0)) * (f1 - f0)
  end

  def self.interp4(x, y, x1, x2, y1, y2, fx1y1, fx1y2, fx2y1, fx2y2)
    '''
    Returns the bilinear interpolation between four results.
    '''

    return (fx1y1 / ((x2 - x1) * (y2 - y1))) * (x2 - x) * (y2 - y) \
          + (fx2y1 / ((x2 - x1) * (y2 - y1))) * (x - x1) * (y2 - y) \
          + (fx1y2 / ((x2 - x1) * (y2 - y1))) * (x2 - x) * (y - y1) \
          + (fx2y2 / ((x2 - x1) * (y2 - y1))) * (x - x1) * (y - y1)
  end

  def self.biquadratic(x, y, c)
    '''
    Description:
    ------------
        Calculate the result of a biquadratic polynomial with independent variables
        x and y, and a list of coefficients, c:
        z = c[1] + c[2]*x + c[3]*x**2 + c[4]*y + c[5]*y**2 + c[6]*x*y
    Inputs:
    -------
        x       float      independent variable 1
        y       float      independent variable 2
        c       tuple      list of 6 coeffients [floats]
    Outputs:
    --------
        z       float      result of biquadratic polynomial
    '''
    if c.length != 6
      puts 'Error: There must be 6 coefficients in a biquadratic polynomial'
    end
    z = c[0] + c[1] * x + c[2] * x**2 + c[3] * y + c[4] * y**2 + c[5] * y * x
    return z
  end

  def self.quadratic(x, c)
    '''
    Description:
    ------------
        Calculate the result of a quadratic polynomial with independent variable
        x and a list of coefficients, c:

        y = c[1] + c[2]*x + c[3]*x**2

    Inputs:
    -------
        x       float      independent variable
        c       tuple      list of 6 coeffients [floats]

    Outputs:
    --------
        y       float      result of biquadratic polynomial
    '''
    if c.size != 3
      puts 'Error: There must be 3 coefficients in a quadratic polynomial'
    end
    y = c[0] + c[1] * x + c[2] * x**2

    return y
  end

  def self.bicubic(x, y, c)
    '''
    Description:
    ------------
        Calculate the result of a bicubic polynomial with independent variables
        x and y, and a list of coefficients, c:

        z = c[1] + c[2]*x + c[3]*y + c[4]*x**2 + c[5]*x*y + c[6]*y**2 + \
            c[7]*x**3 + c[8]*y*x**2 + c[9]*x*y**2 + c[10]*y**3

    Inputs:
    -------
        x       float      independent variable 1
        y       float      independent variable 2
        c       tuple      list of 10 coeffients [floats]

    Outputs:
    --------
        z       float      result of bicubic polynomial
    '''
    if c.size != 10
      puts 'Error: There must be 10 coefficients in a bicubic polynomial'
    end
    z = c[0] + c[1] * x + c[2] * y + c[3] * x**2 + c[4] * x * y + c[5] * y**2 + \
        c[6] * x**3 + c[7] * y * x**2 + c[8] * x * y**2 + c[9] * y**3

    return z
  end

  def self.Iterate(x0, f0, x1, f1, x2, f2, icount, cvg)
    '''
    Description:
    ------------
        Determine if a guess is within tolerance for convergence
        if not, output a new guess using the Newton-Raphson method
    Source:
    -------
        Based on XITERATE f77 code in ResAC (Brandemuehl)
    Inputs:
    -------
        x0      float    current guess value
        f0      float    value of function f(x) at current guess value
        x1,x2   floats   previous two guess values, used to create quadratic
                         (or linear fit)
        f1,f2   floats   previous two values of f(x)
        icount  int      iteration count
        cvg     bool     Has the iteration reached convergence?
    Outputs:
    --------
        x_new   float    new guess value
        cvg     bool     Has the iteration reached convergence?
        x1,x2   floats   updated previous two guess values, used to create quadratic
                         (or linear fit)
        f1,f2   floats   updated previous two values of f(x)
    Example:
    --------
        # Find a value of x that makes f(x) equal to some specific value f:
        # initial guess (all values of x)
        x = 1.0
        x1 = x
        x2 = x
        # initial error
        error = f - f(x)
        error1 = error
        error2 = error
        itmax = 50  # maximum iterations
        cvg = False # initialize convergence to "False"
        for i in range(1,itmax+1):
            error = f - f(x)
            x,cvg,x1,error1,x2,error2 = \
                                     Iterate(x,error,x1,error1,x2,error2,i,cvg)
            if cvg:
                break
        if cvg:
            print "x converged after", i, :iterations"
        else:
            print "x did NOT converge after", i, "iterations"
        print "x, when f(x) is", f,"is", x
    '''

    tolRel = 1e-5
    dx = 0.1

    # Test for convergence
    if (((x0 - x1).abs < tolRel * [x0.abs, Constants.small].max) && (icount != 1)) || (f0 == 0)
      x_new = x0
      cvg = true
    else
      cvg = false

      if icount == 1 # Perturbation
        mode = 1
      elsif icount == 2 # Linear fit
        mode = 2
      else # Quadratic fit
        mode = 3
      end

      if mode == 3
        # Quadratic fit
        if x0 == x1 # If two xi are equal, use a linear fit
          x1 = x2
          f1 = f2
          mode = 2
        elsif x0 == x2 # If two xi are equal, use a linear fit
          mode = 2
        else
          # Set up quadratic coefficients
          c = ((f2 - f0) / (x2 - x0) - (f1 - f0) / (x1 - x0)) / (x2 - x1)
          b = (f1 - f0) / (x1 - x0) - (x1 + x0) * c
          a = f0 - (b + c * x0) * x0

          if c.abs < Constants.small # If points are co-linear, use linear fit
            mode = 2
          elsif ((a + (b + c * x1) * x1 - f1) / f1).abs > Constants.small
            # If coefficients do not accurately predict data points due to
            # round-off, use linear fit
            mode = 2
          else
            d = b**2 - 4.0 * a * c # calculate discriminant to check for real roots
            if d < 0.0 # if no real roots, use linear fit
              mode = 2
            else
              if d > 0.0 # if real unequal roots, use nearest root to recent guess
                x_new = (-b + Math.sqrt(d)) / (2 * c)
                x_other = -x_new - b / c
                if (x_new - x0).abs > (x_other - x0).abs
                  x_new = x_other
                end
              else # If real equal roots, use that root
                x_new = -b / (2 * c)
              end

              if (f1 * f0 > 0) && (f2 * f0 > 0) # If the previous two f(x) were the same sign as the new
                if f2.abs > f1.abs
                  x2 = x1
                  f2 = f1
                end
              else
                if f2 * f0 > 0
                  x2 = x1
                  f2 = f1
                end
              end
              x1 = x0
              f1 = f0
            end
          end
        end
      end

      if mode == 2
        # Linear Fit
        m = (f1 - f0) / (x1 - x0)
        if m == 0 # If slope is zero, use perturbation
          mode = 1
        else
          x_new = x0 - f0 / m
          x2 = x1
          f2 = f1
          x1 = x0
          f1 = f0
        end
      end

      if mode == 1
        # Perturbation
        if x0.abs > Constants.small
          x_new = x0 * (1 + dx)
        else
          x_new = dx
        end
        x2 = x1
        f2 = f1
        x1 = x0
        f1 = f0
      end
    end
    return x_new, cvg, x1, f1, x2, f2
  end
end

# Adapted from https://stackoverflow.com/questions/6934185/ruby-net-http-following-redirects
class UrlResolver
  def self.fetch(uri_str, outfile, agent = 'curl/7.43.0', max_attempts = 10, timeout = 10)
    attempts = 0
    cookie = nil

    until attempts >= max_attempts
      attempts += 1

      url = URI.parse(uri_str)
      http = Net::HTTP.new(url.host, url.port)
      http.open_timeout = timeout
      http.read_timeout = timeout
      path = url.path
      path = '/' if path == ''
      path += '?' + url.query unless url.query.nil?

      params = { 'User-Agent' => agent, 'Accept' => '*/*' }
      params['Cookie'] = cookie unless cookie.nil?
      request = Net::HTTP::Get.new(path, params)

      if url.instance_of?(URI::HTTPS)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      http.request request do |response|
        case response
        when Net::HTTPSuccess then
          total = response.header['Content-Length'].to_i
          if total == 0
            fail 'Did not successfully download zip file.'
          end

          size = 0
          progress = 0
          open outfile, 'wb' do |io|
            response.read_body do |chunk|
              io.write chunk
              size += chunk.size
              new_progress = (size * 100) / total
              unless new_progress == progress
                puts 'Downloading %s (%3d%%) ' % [url.path, new_progress]
              end
              progress = new_progress
            end
          end
          return
        when Net::HTTPRedirection then
          location = response['Location']
          cookie = response['Set-Cookie']
          new_uri = URI.parse(location)
          uri_str = if new_uri.relative?
                      url + location
                    else
                      new_uri.to_s
                    end
        else
          raise 'Unexpected response: ' + response.inspect
        end
      end

    end
    raise 'Too many http redirects' if attempts == max_attempts
  end
end
